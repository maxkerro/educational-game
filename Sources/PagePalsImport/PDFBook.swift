import Foundation
import PDFKit
import CoreGraphics

public enum PDFBookError: Error {
    case cannotOpen
    case pageOutOfRange
    case renderFailed
}

/// A PDF workbook opened for import. Renders pages to bitmaps for OCR and display.
public final class PDFBook {
    private let document: PDFDocument
    /// PDFKit is not safe to draw from two threads at once; the page scan and the page view both render.
    private let renderLock = NSLock()

    public var pageCount: Int { document.pageCount }

    public init(url: URL) throws {
        guard let doc = PDFDocument(url: url) else { throw PDFBookError.cannotOpen }
        self.document = doc
    }

    /// Renders one page (0-based) to a bitmap at the given resolution.
    public func renderPage(_ index: Int, dpi: CGFloat = 200) throws -> CGImage {
        renderLock.lock()
        defer { renderLock.unlock() }
        guard let page = document.page(at: index) else { throw PDFBookError.pageOutOfRange }

        let bounds = page.bounds(for: .mediaBox)
        let scale = dpi / 72.0
        let width = max(1, Int((bounds.width * scale).rounded()))
        let height = max(1, Int((bounds.height * scale).rounded()))

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw PDFBookError.renderFailed }

        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -bounds.minX, y: -bounds.minY)
        page.draw(with: .mediaBox, to: context)

        guard let image = context.makeImage() else { throw PDFBookError.renderFailed }
        return image
    }
}
