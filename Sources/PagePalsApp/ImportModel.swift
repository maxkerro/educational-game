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

        Task {
            let outcome = await Task.detached(priority: .userInitiated) { () -> Result<(CGImage, [RecognizedLine], [PageRegion], [PageRect], [PageRect]), Error> in
                Result {
                    let rendered = try book.renderPage(index)
                    let found = try PageOCR.recognize(rendered)
                    // Ignore text when looking for pictures. Skip very unsure lines.
                    let words = found.filter { $0.confidence >= 0.5 }.flatMap { $0.words }
                    let regions = PictureFinder.find(in: rendered, textWords: words)
                    let circles = CircleFinder.findEmpty(in: rendered, textWords: words)
                    let bars = BlankFinder.find(in: rendered)
                    return (rendered, found, regions, circles, bars)
                }
            }.value

            switch outcome {
            case .success(let (rendered, found, foundRegions, foundCircles, foundBars)):
                image = NSImage(cgImage: rendered, size: NSSize(width: rendered.width, height: rendered.height))
                lines = found
                regions = foundRegions
                crops = Self.cutOut(foundRegions, from: rendered)
                pageIndex = index
                pageBitmap = rendered
                circles = foundCircles
                blanks = foundBars
                tasks = TaskBuilder
                    .buildTasks(
                        lines: found.map { PageText(text: $0.text, box: $0.box) },
                        emptyCircles: foundCircles,
                        blanks: foundBars,
                        idPrefix: "p\(index + 1)",
                        pageAspect: Double(rendered.width) / Double(rendered.height)
                    )
                    .map { task in
                        var task = task
                        if let saved = keys[task.id] { task.key = saved }
                        return task
                    }
                let pictureCount = foundRegions.filter { $0.kind == .picture }.count
                status = "Page \(index + 1) of \(book.pageCount): \(found.count) text lines, \(pictureCount) pictures, \(foundCircles.count) empty circles, \(tasks.count) task(s)"
            case .failure(let error):
                status = "Could not read page \(index + 1): \(error.localizedDescription)"
            }
            isWorking = false
        }
    }

    /// Remembers the answers a parent entered for a task (kept on this Mac, per book file name).
    func saveKey(_ key: AnswerKey, for taskID: String) {
        keys[taskID] = key
        KeyStore.save(keys, book: bookName)
        if let i = tasks.firstIndex(where: { $0.id == taskID }) { tasks[i].key = key }
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
