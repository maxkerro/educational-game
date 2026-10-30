import SwiftUI
import AppKit
import PagePalsCore
import PagePalsImport

/// A picture cut out of the page, ready to be reused in an interactive task.
struct PictureCrop: Identifiable {
    let id = UUID()
    let image: NSImage
    let region: PageRegion
}

@MainActor
final class ImportModel: ObservableObject {
    @Published private(set) var pageCount = 0
    @Published private(set) var pageIndex = 0
    @Published private(set) var image: NSImage?
    @Published private(set) var lines: [RecognizedLine] = []
    @Published private(set) var regions: [PageRegion] = []
    @Published private(set) var crops: [PictureCrop] = []
    @Published private(set) var circles: [PageRect] = []
    @Published private(set) var blanks: [PageRect] = []
    @Published private(set) var tasks: [PlayTask] = []
    @Published private(set) var pageBitmap: CGImage?
    @Published private(set) var status = "Open a PDF workbook to begin."
    @Published private(set) var isWorking = false
    /// "Looking for answer pages ..." while the book is read in the background, then a short result.
    @Published private(set) var keyStatus = ""
    /// 0...1 while a whole book is being imported into the library, otherwise `nil`.
    @Published private(set) var importFraction: Double?
    @Published private(set) var library: [LessonLibrary.Entry] = []
    /// The book opened from the library (pages are saved pictures), or `nil` when a PDF is open.
    @Published private(set) var libraryID: String?
    private var libraryPack: LessonPack?
    private let lessons = LessonLibrary(root: BookImporter.libraryRoot)
    private var importTask: Task<Void, Never>?
    private var cancelFlag = CancelFlag()

    /// Text of every page that has been read (page index -> lines). Filled by the background scan and by `show`.
    private var pageText: [Int: [RecognizedLine]] = [:]
    private var bookKey: [AnswerPages.Entry] = []
    private var scanTask: Task<Void, Never>?
    /// Raised when another book is opened; work started for an older book must not write its results.
    private var generation = 0
    /// The book key was found while a page was loading: show the page again when it is done.
    private var refreshAfterShow = false

    private var book: PDFBook?
    private var bookName = "book"
    private var bookFingerprint: UInt64 = 0
    private var keys: [String: AnswerKey] = [:]

    var canGoBack: Bool { (book != nil || libraryPack != nil) && pageIndex > 0 && !isWorking }
    var canGoForward: Bool { (book != nil || libraryPack != nil) && pageIndex < pageCount - 1 && !isWorking }
    /// Tells books apart: stars and library folders use it, because task ids ("p1-t2") repeat in every book.
    var bookScope: String { libraryID ?? BookID.make(fileName: bookName, fingerprint: bookFingerprint) }
    var canImportBook: Bool { book != nil && importTask == nil }
    var language: BookLanguage {
        if let pack = libraryPack { return BookLanguage(rawValue: pack.language) ?? .english }
        return BookLanguage.detect(from: lines.map(\.text))
    }

    init() { library = lessons.list() }

    // MARK: Library (PP-004) and whole-book import (PP-003, PP-005)

    /// Reads every page of the open PDF into the library. Pages already done are not read again.
    func importBook() {
        guard let book, importTask == nil else { return }
        let id = BookID.make(fileName: bookName, fingerprint: bookFingerprint)
        let title = BookID.title(fileName: bookName)
        let scope = bookScope
        let flag = CancelFlag()
        cancelFlag = flag
        let total = book.pageCount
        let lessons = lessons
        importFraction = 0
        status = "Importing \(title) ..."
        let report: @Sendable (ImportProgress) -> Void = { [weak self] p in
            Task { @MainActor in
                guard let self, self.importTask != nil else { return }
                guard !flag.isRaised else { return }
                self.importFraction = p.fraction
                self.status = "Importing \(title): page \(p.finished.count) of \(total)"
            }
        }
        importTask = Task { [weak self] in
            let result = await Task.detached(priority: .utility) {
                BookImporter.run(book: book, id: id, title: title, parentKeys: { KeyStore.load(book: scope) }, library: lessons, cancel: flag, progress: report)
            }.value
            guard let self else { return }
            self.importFraction = nil
            self.importTask = nil
            self.library = lessons.list()
            var parts: [String] = []
            if result.progress.isDone && result.failed.isEmpty {
                parts.append("\(title) is in the library (\(total) pages).")
            } else if result.progress.cancelled {
                parts.append("Import stopped at \(result.progress.finished.count) of \(total) pages. Import again to continue.")
            }
            if !result.failed.isEmpty {
                let shown = result.failed.prefix(8).map(String.init).joined(separator: ", ")
                let more = result.failed.count > 8 ? " and \(result.failed.count - 8) more" : ""
                parts.append("\(title): page(s) \(shown)\(more) could not be read or saved; import again to retry them.")
            }
            if !result.unmatchedKeys.isEmpty {
                parts.append("\(result.unmatchedKeys.count) typed answer(s) did not fit a task of the imported book (cut spreads); please set them again.")
                // reported once, then dropped, so the message does not come back with every import
                for id in result.unmatchedKeys { self.keys[id] = nil }
                KeyStore.save(self.keys, book: scope)
            }
            if parts.isEmpty { parts.append("Import finished at \(result.progress.finished.count) of \(total) pages.") }
            self.status = parts.joined(separator: " ")
        }
    }

    func cancelImport() {
        cancelFlag.raise()
        status = "Stopping after this page ..."
    }

    func openFromLibrary(id: String) {
        guard importTask == nil, let pack = try? lessons.load(id: id), !pack.pages.isEmpty else {
            status = "Could not open that book from the library."
            return
        }
        scanTask?.cancel()
        generation += 1
        book = nil
        isWorking = false
        refreshAfterShow = false
        keyStatus = ""
        libraryID = id
        libraryPack = pack
        // answers typed earlier (PDF open) and answers already in the pack are one list
        keys = KeyStore.load(book: id).merging(PackMerge.typedKeys(in: pack)) { stored, _ in stored }
        pageCount = pack.pages.count
        pageIndex = 0
        showLibraryPage(0)
    }

    func deleteFromLibrary(id: String) {
        try? lessons.delete(id: id)
        KeyStore.clear(book: id)
        if libraryID == id { libraryID = nil; libraryPack = nil; image = nil; tasks = []; pageBitmap = nil; pageCount = 0 }
        library = lessons.list()
    }

    private func showLibraryPage(_ index: Int) {
        guard let pack = libraryPack, let id = libraryID, index >= 0, index < pack.pages.count else { return }
        let page = pack.pages[index]
        guard let url = lessons.imageURL(named: page.imageFile, book: id),
              let picture = NSImage(contentsOf: url),
              let cg = picture.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            status = "The picture of page \(index + 1) is missing."
            return
        }
        image = picture
        pageBitmap = cg
        lines = []
        regions = []
        crops = []
        circles = []
        blanks = []
        tasks = page.tasks
        pageIndex = index
        let printed = page.number > 0 ? "page \(page.number)" : "page \(index + 1)"
        status = "\(pack.title), \(printed) (\(index + 1) of \(pack.pages.count)): \(tasks.count) task(s)"
    }

    func open(url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let opened = try PDFBook(url: url)
            guard let fingerprint = BookImporter.fingerprint(of: url, pageCount: opened.pageCount) else {
                status = "Could not read that file."
                return
            }
            book = opened
            libraryID = nil
            libraryPack = nil
            bookName = url.lastPathComponent
            bookFingerprint = fingerprint
            keys = KeyStore.load(book: bookScope)
            scanTask?.cancel()
            generation += 1
            isWorking = false
            refreshAfterShow = false
            pageText = [:]
            bookKey = []
            keyStatus = ""
            pageCount = opened.pageCount
            pageIndex = 0
            image = nil
            lines = []
            regions = []
            crops = []
            circles = []
            blanks = []
            tasks = []
            pageBitmap = nil
            status = "\(url.lastPathComponent): \(opened.pageCount) pages"
            show(page: 0)
            scanForAnswerPages(opened)
        } catch {
            status = "Could not open that file as a PDF."
        }
    }

    func next() { show(page: pageIndex + 1) }
    func previous() { show(page: pageIndex - 1) }

    func show(page index: Int) {
        if libraryPack != nil { showLibraryPage(index); return }
        guard let book, index >= 0, index < book.pageCount, !isWorking else { return }
        isWorking = true
        status = "Reading page \(index + 1) ..."
        let cachedLines = pageText[index]
        let entries = bookKey
        let gen = generation

        Task {
            let outcome = await Task.detached(priority: .userInitiated) { () -> Result<(CGImage, [RecognizedLine], [PageRegion], [PageRect], [PageRect], [PageRect]), Error> in
                Result {
                    let rendered = try book.renderPage(index)
                    let found = try cachedLines ?? PageOCR.recognize(rendered)
                    // Ignore text when looking for pictures. Skip very unsure lines.
                    let words = found.filter { $0.confidence >= 0.5 }.flatMap { $0.words }
                    let regions = PictureFinder.find(in: rendered, textWords: words)
                    let circles = CircleFinder.findEmpty(in: rendered, textWords: words)
                    let bars = BlankFinder.find(in: rendered)
                    let ticks = TickFinder.find(in: rendered)
                    return (rendered, found, regions, circles, bars, ticks)
                }
            }.value

            // Another book was opened meanwhile: its own `show` owns the screen and `isWorking`.
            guard gen == generation else { return }

            switch outcome {
            case .success(let (rendered, found, foundRegions, foundCircles, foundBars, foundTicks)):
                image = NSImage(cgImage: rendered, size: NSSize(width: rendered.width, height: rendered.height))
                lines = found
                regions = foundRegions
                crops = Self.cutOut(foundRegions, from: rendered)
                pageIndex = index
                pageBitmap = rendered
                circles = foundCircles
                blanks = foundBars
                pageText[index] = found
                let texts = found.map { PageText(text: $0.text, box: $0.box) }
                let aspect = Double(rendered.width) / Double(rendered.height)
                let built = TaskBuilder.buildTasks(
                    lines: texts,
                    emptyCircles: foundCircles,
                    blanks: foundBars,
                    tickCircles: foundTicks,
                    pictures: foundRegions.filter { $0.kind == .picture }.map { $0.box },
                    idPrefix: "p\(index + 1)",
                    pageAspect: aspect
                )
                // the key printed at the back of the book (needs the printed page number), then what a grown-up typed
                tasks = BookKeys.apply(entries, to: built, lines: texts, pageAspect: aspect)
                    .map { task in
                        var task = task
                        if let saved = keys[task.id] {
                            task.key = saved
                            task.keySource = .parent
                        }
                        return task
                    }
                let pictureCount = foundRegions.filter { $0.kind == .picture }.count
                status = "Page \(index + 1) of \(book.pageCount): \(found.count) text lines, \(pictureCount) pictures, \(foundCircles.count) empty circles, \(foundTicks.count) tick circles, \(tasks.count) task(s)"
            case .failure(let error):
                status = "Could not read page \(index + 1): \(error.localizedDescription)"
            }
            isWorking = false
            if refreshAfterShow {
                refreshAfterShow = false
                show(page: pageIndex)
            }
        }
    }

    /// Remembers the answers a parent entered for a task (kept on this Mac, per book).
    func saveKey(_ key: AnswerKey, for taskID: String) {
        // one list of typed answers per book (KeyStore), and the library copy follows it, so neither side goes stale
        keys[taskID] = key
        KeyStore.save(keys, book: bookScope)
        if let pack = libraryPack, let id = libraryID {
            let updated = PackMerge.setKey(key, for: taskID, in: pack)
            libraryPack = updated
            try? lessons.save(updated, id: id)
        } else if importTask == nil, let stored = try? lessons.load(id: bookScope) {
            try? lessons.save(PackMerge.setKey(key, for: taskID, in: stored), id: bookScope)
        }
        if let i = tasks.firstIndex(where: { $0.id == taskID }) {
            tasks[i].key = key
            tasks[i].keySource = .parent
        }
    }

    /// Reads the text of every page in the background, finds the answer key pages and remembers their entries.
    /// Pages already read are not read again. The current page is updated when the key is found.
    private func scanForAnswerPages(_ opened: PDFBook) {
        let total = opened.pageCount
        let gen = generation
        scanTask = Task { [weak self] in
            var pages: [[PageText]] = []
            for index in 0..<total {
                guard !Task.isCancelled, let self, self.generation == gen else { return }
                self.keyStatus = "Looking for answer pages: \(index + 1) of \(total) ..."
                var lines = self.pageText[index]
                if lines == nil {
                    lines = await Task.detached(priority: .utility) { () -> [RecognizedLine]? in
                        guard let image = try? opened.renderPage(index) else { return nil }
                        return try? PageOCR.recognize(image)
                    }.value
                    // the book may have changed while this page was read
                    guard !Task.isCancelled, self.generation == gen else { return }
                    if let read = lines { self.pageText[index] = read }
                }
                pages.append((lines ?? []).map { PageText(text: $0.text, box: $0.box) })
            }
            guard !Task.isCancelled, let self, self.generation == gen else { return }
            let entries = BookKeys.entries(pages: pages)
            self.bookKey = entries
            self.keyStatus = entries.isEmpty
                ? "No answer pages found in this book."
                : "Answer pages found: \(entries.count) answer lines."
            guard !entries.isEmpty, self.book != nil else { return }
            if self.isWorking { self.refreshAfterShow = true } else { self.show(page: self.pageIndex) }
        }
    }

    /// Crops every picture region (with a small margin) out of the page bitmap.
    private static func cutOut(_ regions: [PageRegion], from page: CGImage) -> [PictureCrop] {
        let bounds = CGRect(x: 0, y: 0, width: page.width, height: page.height)
        var result: [PictureCrop] = []
        for region in regions where region.kind == .picture {
            let pad = 8.0
            let rect = CGRect(
                x: region.box.x * Double(page.width) - pad,
                y: region.box.y * Double(page.height) - pad,
                width: region.box.width * Double(page.width) + 2 * pad,
                height: region.box.height * Double(page.height) + 2 * pad
            ).intersection(bounds).integral
            guard !rect.isEmpty, let piece = page.cropping(to: rect) else { continue }
            let image = NSImage(cgImage: piece, size: NSSize(width: piece.width, height: piece.height))
            result.append(PictureCrop(image: image, region: region))
        }
        return result
    }
}
