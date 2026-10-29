import Foundation
import CoreGraphics
import CoreText
import PagePalsCore

/// Ten pages made by the app itself, with every shape at a known place (PP-016). They contain no copyrighted
/// content: plain words and coloured blocks. They let the importer be measured and checked without a real book.
public struct TestPage {
    public let name: String
    public let image: CGImage
    /// Task numbers printed in the headers ("1." ... ).
    public let headerNumbers: [Int]
    public let circles: [PageRect]
    public let bars: [PageRect]
    public let ticks: [PageRect]
    public let pictures: [PageRect]
}

public enum TestPages {
    /// The kind of task printed on a test page.
    public enum Spec: Equatable, Sendable {
        case numbering(Int), fillIn(Int), tick(Int), matching, crossword, wordSearch, choice, open, ordering

        public var kind: String {
            switch self {
            case .numbering: return "numbering"
            case .fillIn: return "fillIn"
            case .tick: return "tick"
            case .matching: return "matching"
            case .crossword: return "crossword"
            case .wordSearch: return "wordSearch"
            case .choice: return "choice"
            case .open: return "open"
            case .ordering: return "ordering"
            }
        }

        var title: String {
            switch self {
            case .numbering: return "Number the pictures."
            case .fillIn: return "Count and write."
            case .tick: return "Correct or wrong? Tick."
            case .matching: return "Draw lines from the pictures to the words."
            case .crossword: return "Complete the crossword."
            case .wordSearch: return "Find the words."
            case .choice: return "Read and choose."
            case .open: return "Colour the picture."
            case .ordering: return "Put the sentences in order."
            }
        }
    }

    /// The page kind that shows a task kind. Every task kind must be named here (no `default`), so a new
    /// kind in the app cannot be forgotten by the test pages.
    public static func pageKind(for kind: TaskKind) -> String {
        switch kind {
        case .numberInOrder: return "numbering"
        case .fillIn: return "fillIn"
        case .trueFalse: return "tick"
        case .matching: return "matching"
        case .crossword: return "crossword"
        case .wordSearch: return "wordSearch"
        case .multipleChoice: return "choice"
        case .openTask: return "open"
        case .ordering: return "ordering"
        }
    }

    public static var kinds: [String] { TaskKind.allCases.map { pageKind(for: $0) } }

    /// What is printed on each page. Every kind of task appears at least twice.
    public static let specs: [[Spec]] = [
        [.numbering(4), .fillIn(4)],
        [.tick(4), .choice],
        [.matching, .open],
        [.crossword, .numbering(3)],
        [.wordSearch, .fillIn(3)],
        [.numbering(5), .choice],
        [.tick(3), .open, .ordering],
        [.matching, .fillIn(4)],
        [.crossword, .open],
        [.wordSearch, .choice, .ordering]
    ]

    public static var count: Int { specs.count }

    static let width = 1754.0
    static let height = 2480.0

    public static func page(_ index: Int) -> TestPage {
        let list = specs[index]
        let ctx = CGContext(data: nil, width: Int(width), height: Int(height), bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(gray: 1, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        // from here on y runs from the top of the page, like page units
        ctx.translateBy(x: 0, y: height)
        ctx.scaleBy(x: 1, y: -1)
        ctx.textMatrix = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: 0)

        var circles: [PageRect] = [], bars: [PageRect] = [], ticks: [PageRect] = [], pictures: [PageRect] = []
        var numbers: [Int] = []
        func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> PageRect {
            PageRect(x: x / width, y: y / height, width: w / width, height: h / height)
        }
        func text(_ s: String, _ x: Double, _ y: Double, size: Double = 36) {
            ctx.setFillColor(gray: 0, alpha: 1)
            let font = CTFontCreateWithName("Helvetica" as CFString, CGFloat(size), nil)
            let attributes: [NSAttributedString.Key: Any] = [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorFromContextAttributeName as String): true
            ]
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: s, attributes: attributes))
            ctx.textPosition = CGPoint(x: x, y: y)
            CTLineDraw(line, ctx)
        }
        func picture(_ x: Double, _ y: Double, _ size: Double, _ shade: Int) {
            let colours: [(CGFloat, CGFloat, CGFloat)] = [(0.9, 0.2, 0.2), (0.2, 0.5, 0.9), (0.2, 0.7, 0.3), (0.95, 0.65, 0.1), (0.6, 0.3, 0.8)]
            let c = colours[shade % colours.count]
            ctx.setFillColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
            ctx.fill(CGRect(x: x, y: y, width: size, height: size))
            ctx.setFillColor(red: 1 - c.0 * 0.5, green: 1 - c.1 * 0.5, blue: 1 - c.2 * 0.5, alpha: 1)
            ctx.fillEllipse(in: CGRect(x: x + size * 0.25, y: y + size * 0.25, width: size * 0.5, height: size * 0.5))
            pictures.append(rect(x, y, size, size))
        }

        var y = 160.0
        for (n, spec) in list.enumerated() {
            numbers.append(n + 1)
            text("\(n + 1). \(spec.title)", 120, y, size: 38)
            y += 50
            switch spec {
            case .numbering(let count):
                for i in 0..<count {
                    let x = 160.0 + Double(i) * 300
                    picture(x, y + 10, 140, i + n)
                    let cy = y + 10 + 140 + 80
                    ctx.setStrokeColor(gray: 0, alpha: 1)
                    ctx.setLineWidth(3)
                    ctx.strokeEllipse(in: CGRect(x: x + 70 - 14, y: cy - 14, width: 28, height: 28))
                    circles.append(rect(x + 70 - 14, cy - 14, 28, 28))
                }
                y += 10 + 140 + 80 + 14 + 90
            case .fillIn(let count):
                for i in 0..<count {
                    let ry = y + 50 + Double(i) * 80
                    text("\(i + 2) + \(i + 3) =", 200, ry, size: 40)
                    ctx.setFillColor(gray: 0.82, alpha: 1)
                    ctx.fill(CGRect(x: 520, y: ry - 30, width: 220, height: 30))
                    bars.append(rect(520, ry - 30, 220, 30))
                }
                y += Double(count) * 80 + 100
            case .tick(let rows):
                text("correct", 1020, y + 40, size: 30)
                text("wrong", 1240, y + 40, size: 30)
                for i in 0..<rows {
                    let ry = y + 100 + Double(i) * 90
                    text("The sun is hot (\(i + 1)).", 200, ry, size: 36)
                    for cx in [1060.0, 1270.0] {
                        let rect0 = CGRect(x: cx - 16, y: ry - 30, width: 32, height: 32)
                        ctx.setFillColor(gray: 0.86, alpha: 1)
                        ctx.fillEllipse(in: rect0)
                        ctx.setStrokeColor(gray: 0.55, alpha: 1)
                        ctx.setLineWidth(3)
                        ctx.strokeEllipse(in: rect0)
                        ticks.append(rect(rect0.minX, rect0.minY, 32, 32))
                    }
                }
                y += 100 + Double(rows) * 90 + 60
            case .matching:
                let words = ["cat", "dog", "sun"]
                for i in 0..<3 {
                    let ry = y + 20 + Double(i) * 170
                    picture(200, ry, 120, i + n)
                    text(words[(i + 1) % 3], 1000, ry + 80, size: 44)
                }
                y += 20 + 3 * 170 + 50
            case .crossword:
                ctx.setStrokeColor(gray: 0, alpha: 1)
                ctx.setLineWidth(3)
                for row in 0..<5 {
                    for col in 0..<5 where (row + col) % 2 == 0 || row == 2 {
                        ctx.stroke(CGRect(x: 240 + Double(col) * 72, y: y + 20 + Double(row) * 72, width: 72, height: 72))
                    }
                }
                text("across: sun, hat", 800, y + 120, size: 36)
                y += 20 + 5 * 72 + 70
            case .wordSearch:
                let grid = ["CATSUN", "DOGHAT", "SUNCAT", "HATDOG", "CATDOG", "SUNHAT"]
                for (i, row) in grid.enumerated() {
                    text(row.map(String.init).joined(separator: "  "), 240, y + 60 + Double(i) * 62, size: 40)
                }
                text("cat  dog  sun  hat", 900, y + 120, size: 36)
                y += 60 + 6 * 62 + 50
            case .choice:
                text("The cat is on the mat.  A) big   B) red   C) fast", 200, y + 50, size: 36)
                y += 50 + 90
            case .ordering:
                let sentences = ["hot is the sun", "a cat has dog", "we sing a song", "the hat is red"]
                for (i, sentence) in sentences.enumerated() {
                    text(sentence, 240, y + 60 + Double(i) * 70, size: 38)
                }
                y += 60 + 4 * 70 + 50
            case .open:
                ctx.setStrokeColor(gray: 0, alpha: 1)
                ctx.setLineWidth(3)
                ctx.stroke(CGRect(x: 200, y: y + 20, width: 1200, height: 260))
                text("Colour here.", 240, y + 90, size: 36)
                y += 20 + 260 + 70
            }
        }

        return TestPage(name: "page-\(index + 1)", image: ctx.makeImage()!, headerNumbers: numbers,
                        circles: circles, bars: bars, ticks: ticks, pictures: pictures)
    }

    /// What the importer found on one test page, compared with what is printed there.
    public struct Score {
        public let name: String
        public let circles: RecognitionScore.Result
        public let bars: RecognitionScore.Result
        public let ticks: RecognitionScore.Result
        public let pictures: RecognitionScore.Result
        public let headersExpected: Int
        public let headersFound: Int

        public var line: String {
            func f(_ r: RecognitionScore.Result) -> String { "\(r.hits)/\(r.expected)" + (r.extras > 0 ? " (+\(r.extras))" : "") }
            return "\(name): headers \(headersFound)/\(headersExpected), circles \(f(circles)), bars \(f(bars)), ticks \(f(ticks)), pictures \(f(pictures))"
        }
    }

    /// Runs the same steps as the app on a test page (text, headers, circles, bars, tick circles, pictures).
    public static func score(_ page: TestPage) throws -> Score {
        // PAGEPALS_TRACE=1 prints every step with its time, to find a step that is very slow
        let trace = ProcessInfo.processInfo.environment["PAGEPALS_TRACE"] != nil
        var mark = Date()
        func step(_ name: String) {
            guard trace else { return }
            print(String(format: "TRACE  %@: %@ %.1f s", page.name, name, Date().timeIntervalSince(mark)))
            mark = Date()
        }
        let lines = try PageOCR.recognize(page.image)
        step("text recognition")
        let words = lines.filter { $0.confidence >= 0.5 }.flatMap { $0.words }
        let found = Set(lines.compactMap { TaskBuilder.headerParts($0.text)?.number })
        let headersFound = page.headerNumbers.filter { found.contains($0) }.count
        let regions = PictureFinder.find(in: page.image, textWords: words).filter { $0.kind == .picture }.map { $0.box }
        step("pictures")
        let circleBoxes = CircleFinder.findEmpty(in: page.image, textWords: words)
        step("circles")
        let barBoxes = BlankFinder.find(in: page.image)
        step("bars")
        let tickBoxes = TickFinder.find(in: page.image)
        step("ticks")
        return Score(
            name: page.name,
            circles: RecognitionScore.match(expected: page.circles, found: circleBoxes),
            bars: RecognitionScore.match(expected: page.bars, found: barBoxes),
            ticks: RecognitionScore.match(expected: page.ticks, found: tickBoxes),
            pictures: RecognitionScore.match(expected: page.pictures, found: regions, tolerance: 0.05),
            headersExpected: page.headerNumbers.count,
            headersFound: headersFound
        )
    }
}
