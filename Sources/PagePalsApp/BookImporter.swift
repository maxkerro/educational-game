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
    static var libraryRoot: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("PagePals", isDirectory: true).appendingPathComponent("Library", isDirectory: true)
    }

    /// A folder-safe id from a file name: letters, digits, dash and underscore.
    static func bookID(from fileName: String) -> String {
        let stem = (fileName as NSString).deletingPathExtension
        let cleaned = stem.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? Character($0) : "-" }
        let id = String(cleaned).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return id.isEmpty ? "book" : String(id.prefix(80))
    }

    static func title(from fileName: String) -> String {
        let stem = (fileName as NSString).deletingPathExtension
        return stem.isEmpty ? "Book" : stem
    }

    /// The PDF page a book page came from: "p12", "p12a" and "p12b" are all PDF page 12.
    static func pdfPage(of pageID: String) -> Int {
        Int(pageID.dropFirst().prefix { $0.isNumber }) ?? 0
    }

    static func run(
        book: PDFBook,
        id: String,
        title: String,
        library: LessonLibrary,
        cancel: CancelFlag,
        progress: @escaping @Sendable (ImportProgress) -> Void
    ) -> ImportProgress {
        let total = book.pageCount
        let dir = library.root.appendingPathComponent(id, isDirectory: true)
        let progressURL = dir.appendingPathComponent("progress.json")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        var state = ImportProgress.load(from: progressURL, pageCount: total)
        state.resume()
        var pack = (try? library.load(id: id)) ?? LessonPack(title: title, language: "en", pages: [])
        progress(state)

        while let index = state.nextPage {
            if cancel.isRaised {
                state.cancel()
                try? state.save(to: progressURL)
                progress(state)
                return state
            }
            let number = index + 1
            let made = importPage(book: book, index: index, id: id, library: library)
            pack.pages.removeAll { BookImporter.pdfPage(of: $0.id) == number }
            pack.pages.append(contentsOf: made)
            pack.pages.sort { BookImporter.pdfPage(of: $0.id) == BookImporter.pdfPage(of: $1.id) ? $0.id < $1.id : BookImporter.pdfPage(of: $0.id) < BookImporter.pdfPage(of: $1.id) }
            try? library.save(pack, id: id)
            state.finish(index)
            try? state.save(to: progressURL)
            progress(state)
        }

        pack = finish(pack, id: id, library: library)
        try? library.save(pack, id: id)
        return state
    }

    /// One PDF page becomes one or two book pages (a spread is cut at the gutter).
    private static func importPage(book: PDFBook, index: Int, id: String, library: LessonLibrary) -> [BookPage] {
        guard let rendered = try? book.renderPage(index) else { return [] }
        let pieces = PageAnalysis.split(rendered)
        var pages: [BookPage] = []
        for (half, piece) in pieces.enumerated() {
            guard let analysis = try? PageAnalysis.run(piece), let png = PageAnalysis.pngData(piece) else { continue }
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
                if let data = StoredPageText(texts: texts, aspect: aspect).encoded() {
                    try library.writeImage(data, named: "text-\(index + 1)\(suffix).json", book: id)
                }
            } catch { continue }
            let printed = PageNumbers.number(atX: 0.5, lines: texts, pageAspect: aspect) ?? 0
            pages.append(BookPage(id: pageID, number: printed, imageFile: file, tasks: tasks))
        }
        return pages
    }

    /// The book language from the first pages, and the answers from the key pages at the back (parent keys stay).
    private static func finish(_ pack: LessonPack, id: String, library: LessonLibrary) -> LessonPack {
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
        guard !entries.isEmpty else { return pack }
        for (i, page) in pack.pages.enumerated() {
            guard let text = stored[i] else { continue }
            let applied = BookKeys.apply(entries, to: page.tasks, lines: text.texts, pageAspect: text.aspect)
            let byID = Dictionary(applied.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            pack.pages[i].tasks = page.tasks.map { old in
                old.keySource == .parent ? old : (byID[old.id] ?? old)
            }
        }
        return pack
    }
}
