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
    private var keys: [String: AnswerKey] = [:]

    var canGoBack: Bool { book != nil && pageIndex > 0 && !isWorking }
    var canGoForward: Bool { book != nil && pageIndex < pageCount - 1 && !isWorking }

    func open(url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let opened = try PDFBook(url: url)
            book = opened
            bookName = url.lastPathComponent
            keys = KeyStore.load(book: bookName)
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

    /// Remembers the answers a parent entered for a task (kept on this Mac, per book file name).
    func saveKey(_ key: AnswerKey, for taskID: String) {
        keys[taskID] = key
        KeyStore.save(keys, book: bookName)
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
