import Foundation
import CoreGraphics
import PagePalsCore
import PagePalsImport

/// Lets the import loop be stopped from the screen.
final class CancelFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var raised = false
    func raise() { lock.lock(); raised = true; lock.unlock() }
    var isRaised: Bool { lock.lock(); defer { lock.unlock() }; return raised }
}

/// Reads a whole PDF book into the library, page by page (PP-003, PP-004, PP-005).
/// After every page the pack and the progress file are saved, so a stop (or a crash) loses at most one page.
enum BookImporter {
    struct Outcome: Sendable {
        var progress: ImportProgress
        /// PDF pages (1-based) that could not be read or saved; they stay pending for the next import.
        var failed: [Int]
        /// Typed answers (task ids) that matched no task of the imported book, for example on a cut spread.
        /// Answers of pages that failed are not listed: they fit once the page is read.
        var unmatchedKeys: [String] = []
    }

    static var libraryRoot: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("PagePals", isDirectory: true).appendingPathComponent("Library", isDirectory: true)
    }

    /// Start, end and size of the file: cheap, and different for different workbooks.
    static func fingerprint(of url: URL, pageCount: Int) -> UInt64? {
        var parts: [Data] = [Data("\(pageCount)".utf8)]
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        do {
            defer { try? handle.close() }
            let size = (try? handle.seekToEnd()) ?? 0
            parts.append(Data("\(size)".utf8))
            let chunk = 64 * 1024
            try? handle.seek(toOffset: 0)
            if let head = try? handle.read(upToCount: chunk) { parts.append(head) }
            if size > UInt64(chunk) {
                try? handle.seek(toOffset: size - UInt64(chunk))
                if let tail = try? handle.read(upToCount: chunk) { parts.append(tail) }
            }
        }
        return BookID.fingerprint(parts)
    }

    /// `parentKeys` are the answers a grown-up typed while the PDF was open (by task id).
    static func run(
        book: PDFBook,
        id: String,
        title: String,
        parentKeys: @Sendable () -> [String: AnswerKey],
        library: LessonLibrary,
        cancel: CancelFlag,
        progress: @escaping @Sendable (ImportProgress) -> Void
    ) -> Outcome {
        let total = book.pageCount
        let dir = library.root.appendingPathComponent(id, isDirectory: true)
        let progressURL = dir.appendingPathComponent("progress.json")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        var state = ImportProgress.load(from: progressURL, pageCount: total)
        state.resume()
        var pack = (try? library.load(id: id)) ?? LessonPack(title: title, language: "en", pages: [])
        var skipped = Set<Int>()
        progress(state)

        while let index = (0..<total).first(where: { !state.finished.contains($0) && !skipped.contains($0) }) {
            if cancel.isRaised {
                state.cancel()
                try? state.save(to: progressURL)
                progress(state)
                return Outcome(progress: state, failed: skipped.sorted().map { $0 + 1 })
            }
            let number = index + 1
            guard let made = importPage(book: book, index: index, id: id, library: library) else {
                skipped.insert(index)
                continue
            }
            let next = PackMerge.replacePage(in: pack, pdfPage: number, with: made)
            do {
                try library.save(next, id: id)
            } catch {
                skipped.insert(index)
                continue
            }
            pack = next
            state.finish(index)
            try? state.save(to: progressURL)
            progress(state)
        }

        let failedPages = Set(skipped.map { $0 + 1 })
        let finished = finish(pack, id: id, parentKeys: parentKeys(), failedPages: failedPages, library: library)
        try? library.save(finished.pack, id: id)
        return Outcome(progress: state, failed: skipped.sorted().map { $0 + 1 }, unmatchedKeys: finished.unmatched)
    }

    /// One PDF page becomes one or two book pages (a spread is cut at the gutter).
    /// `nil` when the page could not be rendered, read or written: it is then tried again next time.
    private static func importPage(book: PDFBook, index: Int, id: String, library: LessonLibrary) -> [BookPage]? {
        guard let rendered = try? book.renderPage(index) else { return nil }
        let pieces = PageAnalysis.split(rendered)
        var pages: [BookPage] = []
        for (half, piece) in pieces.enumerated() {
            guard let analysis = try? PageAnalysis.run(piece), let png = PageAnalysis.pngData(piece) else { return nil }
            let suffix = pieces.count == 2 ? (half == 0 ? "a" : "b") : ""
            let pageID = "p\(index + 1)\(suffix)"
            let aspect = Double(piece.width) / Double(max(1, piece.height))
            let texts = analysis.texts
            let tasks = TaskBuilder.buildTasks(
                lines: texts,
                emptyCircles: analysis.circles,
                blanks: analysis.blanks,
                tickCircles: analysis.ticks,
                pictures: analysis.pictures,
                idPrefix: pageID,
                pageAspect: aspect
            )
            let file = "page-\(index + 1)\(suffix).png"
            do {
                try library.writeImage(png, named: file, book: id)
                guard let data = StoredPageText(texts: texts, aspect: aspect).encoded() else { return nil }
                try library.writeImage(data, named: "text-\(index + 1)\(suffix).json", book: id)
            } catch { return nil }
            // each piece is one page, so the number is looked for on the whole piece
            let printed = PageNumbers.number(atX: 0.5, lines: texts, pageAspect: aspect) ?? 0
            pages.append(BookPage(id: pageID, number: printed, imageFile: file, tasks: tasks))
        }
        return pages
    }

    /// The book language from the first pages, the answers from the key pages at the back, and the answers a
    /// grown-up typed. Typed answers always win.
    private static func finish(_ pack: LessonPack, id: String, parentKeys: [String: AnswerKey], failedPages: Set<Int>, library: LessonLibrary) -> (pack: LessonPack, unmatched: [String]) {
        var pack = pack
        var stored: [StoredPageText?] = []
        for page in pack.pages {
            let name = "text-" + String(page.imageFile.dropFirst(5).dropLast(4)) + ".json"
            let data = library.imageURL(named: name, book: id).flatMap { try? Data(contentsOf: $0) }
            stored.append(data.flatMap { StoredPageText.decode($0) })
        }
        let sample = stored.prefix(12).compactMap { $0 }.flatMap { $0.lines.map(\.text) }
        pack.language = BookLanguage.detect(from: sample).rawValue

        let entries = BookKeys.entries(pages: stored.map { $0?.texts ?? [] })
        var matched = Set<String>()
        for (i, page) in pack.pages.enumerated() {
            var tasks = page.tasks
            if !entries.isEmpty, let text = stored[i] {
                let applied = BookKeys.apply(entries, to: tasks, lines: text.texts, pageAspect: text.aspect)
                let byID = Dictionary(applied.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
                tasks = tasks.map { old in old.keySource == .parent ? old : (byID[old.id] ?? old) }
            }
            let overlaid = PackMerge.overlay(parentKeys, on: tasks)
            tasks = overlaid.tasks
            matched.formUnion(overlaid.matched)
            pack.pages[i].tasks = tasks
        }
        return (pack, PackMerge.unmatched(typed: parentKeys, matched: matched, failedPages: failedPages))
    }
}
