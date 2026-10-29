import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import PagePalsCore

/// Everything the finders see on one page bitmap, and the helpers a whole-book import needs (PP-003, PP-005).
public struct PageAnalysis: Sendable {
    public var lines: [RecognizedLine]
    public var regions: [PageRegion]
    public var circles: [PageRect]
    public var blanks: [PageRect]
    public var ticks: [PageRect]

    public var texts: [PageText] { lines.map { PageText(text: $0.text, box: $0.box) } }

    public var pictures: [PageRect] { regions.filter { $0.kind == .picture }.map { $0.box } }

    /// Reads the text (unless `lines` is given) and runs every finder. Very unsure text lines are ignored by the finders.
    public static func run(_ image: CGImage, lines cached: [RecognizedLine]? = nil) throws -> PageAnalysis {
        let found = try cached ?? PageOCR.recognize(image)
        let words = found.filter { $0.confidence >= 0.5 }.flatMap { $0.words }
        return PageAnalysis(
            lines: found,
            regions: PictureFinder.find(in: image, textWords: words),
            circles: CircleFinder.findEmpty(in: image, textWords: words),
            blanks: BlankFinder.find(in: image),
            ticks: TickFinder.find(in: image)
        )
    }

    /// Darkness (0 white ... 1 black) of every pixel column of a reduced copy of the image.
    static func columnDarkness(_ image: CGImage) -> [Double] {
        guard let bmp = WorkBitmap(image: image, targetWidth: 600) else { return [] }
        var sums = [Double](repeating: 0, count: bmp.width)
        for y in 0..<bmp.height {
            for x in 0..<bmp.width {
                sums[x] += 1 - Double(bmp.mx[y * bmp.width + x]) / 255
            }
        }
        return sums.map { $0 / Double(max(1, bmp.height)) }
    }

    /// One bitmap per book page: a scan of two pages is cut at its gutter, a single page is returned as it is.
    public static func split(_ image: CGImage) -> [CGImage] {
        let aspect = Double(image.width) / Double(max(1, image.height))
        guard PageSplit.isSpread(aspect: aspect) else { return [image] }
        let g = PageSplit.gutter(profile: columnDarkness(image))
        let halves = PageSplit.halves(gutter: g)
        var pieces: [CGImage] = []
        for half in [halves.left, halves.right] {
            let rect = CGRect(
                x: (half.x * Double(image.width)).rounded(),
                y: 0,
                width: (half.width * Double(image.width)).rounded(),
                height: Double(image.height)
            ).intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))
            guard !rect.isEmpty, let piece = image.cropping(to: rect) else { return [image] }
            pieces.append(piece)
        }
        return pieces
    }

    public static func pngData(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, image, nil)
        return CGImageDestinationFinalize(dest) ? data as Data : nil
    }
}
