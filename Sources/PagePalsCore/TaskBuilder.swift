import Foundation

/// One line of recognised text with its place on the page.
public struct PageText: Equatable, Sendable {
    public let text: String
    public let box: PageRect

    public init(text: String, box: PageRect) {
        self.text = text
        self.box = box
    }
}

/// The part of a page that belongs to one numbered book task ("1. Number.").
public struct TaskZone: Equatable, Sendable {
    public let number: Int?
    public let title: String
    public let box: PageRect

    public init(number: Int?, title: String, box: PageRect) {
        self.number = number
        self.title = title
        self.box = box
    }
}

/// Turns what was found on a page (text lines, empty circles) into interactive tasks.
/// Pure geometry and text rules, so it can be checked without a PDF.
public enum TaskBuilder {
    /// A task header is "<number>. <instruction>", for example "1. Number." or
    /// "4. How many lollies? Trace the lines and write." A small pencil icon in front is tolerated
    /// (OCR may read it as one or two stray characters).
    public static func headerParts(_ text: String) -> (number: Int, title: String)? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        var chars = Substring(trimmed)
        // Skip at most 2 stray characters before the number
        var skipped = 0
        while let c = chars.first, !c.isNumber, skipped < 2 {
            chars = chars.dropFirst()
            skipped += 1
        }
        chars = Substring(chars.drop(while: { $0 == " " }))
        var digits = ""
        var rest = chars
        while let c = rest.first, c.isNumber, digits.count < 2 {
            digits.append(c)
            rest = rest.dropFirst()
        }
        guard let number = Int(digits), let sep = rest.first, sep == "." || sep == ")" else { return nil }
        let title = rest.dropFirst().trimmingCharacters(in: .whitespaces)
        let words = title.split(whereSeparator: { $0.isWhitespace })
        guard !words.isEmpty, words.count <= 12 else { return nil }
        return (number, title)
    }

    /// Splits a page into task zones, top to bottom. A two-page spread (wider than tall) is read
    /// as a left and a right page. Without any header a page is one zone.
    /// - Parameter pageAspect: page width divided by height
    public static func zones(from lines: [PageText], pageAspect: Double = 0.7) -> [TaskZone] {
        let columns: [(x: Double, width: Double)] = pageAspect > 1.2 ? [(0, 0.5), (0.5, 0.5)] : [(0, 1)]
        var zones: [TaskZone] = []

        for column in columns {
            let headers = lines
                .compactMap { line -> (PageText, Int, String)? in
                    let centre = line.box.x + line.box.width / 2
                    guard centre >= column.x, centre < column.x + column.width,
                          line.box.x < column.x + column.width * 0.5,
                          let parts = headerParts(line.text) else { return nil }
                    return (line, parts.number, parts.title)
                }
                .sorted { $0.0.box.y < $1.0.box.y }

            if headers.isEmpty {
                zones.append(TaskZone(number: nil, title: "", box: PageRect(x: column.x, y: 0, width: column.width, height: 1)))
                continue
            }
            for (index, header) in headers.enumerated() {
                let top = max(0, header.0.box.y - 0.01)
                let bottom = index + 1 < headers.count ? max(top, headers[index + 1].0.box.y - 0.01) : 1.0
                zones.append(TaskZone(
                    number: header.1,
                    title: header.2,
                    box: PageRect(x: column.x, y: top, width: column.width, height: bottom - top)
                ))
            }
        }
        return zones
    }

    /// Builds one task per zone. A zone with two or more empty circles becomes a
    /// "put the number in each circle" task (`numberInOrder`); other zones become open tasks
    /// that a parent confirms, until more task types are recognised.
    /// - Parameters:
    ///   - emptyCircles: boxes of empty circles found on the page
    ///   - tickCircles: boxes of grey tick circles ("Correct or wrong? Tick.")
    ///   - blanks: boxes of grey answer bars; a bar right of a sum like "three + one =" becomes its blank
    ///   - idPrefix: makes task ids unique across pages, e.g. "p3"
    ///   - pageAspect: page width / height; above 1.2 the page is read as a two-page spread
    public static func buildTasks(lines: [PageText], emptyCircles: [PageRect], blanks: [PageRect] = [], tickCircles: [PageRect] = [], idPrefix: String, pageAspect: Double = 0.7) -> [PlayTask] {
        var tasks: [PlayTask] = []
        for (index, zone) in zones(from: lines, pageAspect: pageAspect).enumerated() {
            let inside = emptyCircles
                .filter { contains(zone.box, centreOf: $0) }
                .sorted { a, b in
                    let rowA = (a.y * 20).rounded(), rowB = (b.y * 20).rounded()
                    return rowA == rowB ? a.x < b.x : a.y < b.y
                }
            let id = "\(idPrefix)-" + (zone.number.map { "t\($0)" } ?? "z\(index + 1)")
            let prompt = zone.title.isEmpty ? "Put the right number into each circle." : zone.title

            // "Tick" tasks have circles too, but they are not number slots
            let isTick = zone.title.lowercased().contains("tick")

            if isTick, let tick = tickTask(id: id, prompt: prompt, zone: zone, lines: lines, circles: tickCircles) {
                tasks.append(tick)
            } else if inside.count >= 2 && !isTick {
                let items = inside.enumerated().map { TaskItem(id: "\(id)-slot\($0.offset + 1)", region: $0.element) }
                tasks.append(PlayTask(id: id, kind: .numberInOrder, prompt: prompt, region: zone.box, items: items, key: nil, confidence: 0.7))
            } else if !isTick, let fill = sumsTask(id: id, prompt: prompt, zone: zone, lines: lines, blanks: blanks) {
                tasks.append(fill)
            } else if !isTick, let fill = answerBarsTask(id: id, prompt: prompt, zone: zone, lines: lines, blanks: blanks) {
                tasks.append(fill)
            } else {
                tasks.append(PlayTask(id: id, kind: .openTask, prompt: prompt, region: zone.box, items: [], key: nil, confidence: 0.3))
            }
        }
        return tasks
    }

    /// A zone with sums ("three + one =") that each have an answer bar to their right becomes a
    /// fill-in task. The answers are calculated, so no answer key is needed.
    private static func sumsTask(id: String, prompt: String, zone: TaskZone, lines: [PageText], blanks: [PageRect]) -> PlayTask? {
        var pairs: [(line: PageText, bar: PageRect, answer: String)] = []
        for line in lines where contains(zone.box, centreOf: line.box) {
            guard let answer = NumberWords.answer(forSum: line.text) else { continue }
            let lineCentreY = line.box.y + line.box.height / 2
            let candidates = blanks.filter { bar in
                let barCentreY = bar.y + bar.height / 2
                return abs(barCentreY - lineCentreY) < max(line.box.height, bar.height) * 0.9
                    && bar.x >= line.box.x + line.box.width - 0.01
                    && contains(zone.box, centreOf: bar)
            }
            if let bar = candidates.min(by: { $0.x < $1.x }) { pairs.append((line, bar, answer)) }
        }
        guard pairs.count >= 2 else { return nil }
        pairs.sort { ($0.bar.y, $0.bar.x) < ($1.bar.y, $1.bar.x) }

        var items: [TaskItem] = []
        var key = AnswerKey()
        for (index, pair) in pairs.enumerated() {
            let itemID = "\(id)-b\(index + 1)"
            items.append(TaskItem(id: itemID, label: pair.line.text, region: pair.bar))
            key.text[itemID] = pair.answer
        }
        return PlayTask(id: id, kind: .fillIn, prompt: prompt, region: zone.box, items: items, key: key, confidence: 0.8, keySource: .calculated)
    }

    /// A zone with two or more grey answer bars but no sums: a write-the-answer task. The answers are
    /// not known, so a grown-up types them once. The word printed right of a bar ("lollies") is its label.
    private static func answerBarsTask(id: String, prompt: String, zone: TaskZone, lines: [PageText], blanks: [PageRect]) -> PlayTask? {
        let bars = blanks
            .filter { contains(zone.box, centreOf: $0) }
            .sorted { a, b in
                let rowA = (a.y * 40).rounded(), rowB = (b.y * 40).rounded()
                return rowA == rowB ? a.x < b.x : a.y < b.y
            }
        guard bars.count >= 2 else { return nil }

        let items = bars.enumerated().map { index, bar -> TaskItem in
            let barCentreY = bar.y + bar.height / 2
            let label = lines
                .filter { line in
                    abs(line.box.y + line.box.height / 2 - barCentreY) < max(line.box.height, bar.height)
                        && line.box.x >= bar.x + bar.width - 0.01
                        && line.box.x - (bar.x + bar.width) < 0.05
                }
                .min(by: { $0.box.x < $1.box.x })?.text
            return TaskItem(id: "\(id)-b\(index + 1)", label: label, region: bar)
        }
        return PlayTask(id: id, kind: .fillIn, prompt: prompt, region: zone.box, items: items, key: nil, confidence: 0.5)
    }

    /// "Correct or wrong? Tick.": grey circles in two columns, one row per sentence. The column headed
    /// "correct" (printed above it) is the "correct" column; without a header the left column is "correct".
    /// The answers are not known here; the AI step or a grown-up provides them.
    private static func tickTask(id: String, prompt: String, zone: TaskZone, lines: [PageText], circles: [PageRect]) -> PlayTask? {
        let inside = circles.filter { contains(zone.box, centreOf: $0) }
        guard inside.count >= 4 else { return nil }

        // split into two columns at the biggest horizontal gap between circle centres
        let byX = inside.sorted { $0.x < $1.x }
        var gapIndex = 0
        var gap = -1.0
        for i in 1..<byX.count where byX[i].x - byX[i - 1].x > gap {
            gap = byX[i].x - byX[i - 1].x
            gapIndex = i
        }
        var left = Array(byX[..<gapIndex]).sorted { $0.y < $1.y }
        var right = Array(byX[gapIndex...]).sorted { $0.y < $1.y }
        guard left.count == right.count, left.count >= 2, gap > 0.02 else { return nil }

        // which column is "correct"?
        func headerX(_ word: String) -> Double? {
            lines.first { contains(zone.box, centreOf: $0.box) && $0.text.lowercased().trimmingCharacters(in: CharacterSet.punctuationCharacters.union(.whitespaces)) == word }
                .map { $0.box.x + $0.box.width / 2 }
        }
        let leftX = left.map { $0.x + $0.width / 2 }.reduce(0, +) / Double(left.count)
        let rightX = right.map { $0.x + $0.width / 2 }.reduce(0, +) / Double(right.count)
        if let correctX = headerX("correct"), let wrongX = headerX("wrong"), abs(correctX - rightX) + abs(wrongX - leftX) < abs(correctX - leftX) + abs(wrongX - rightX) {
            swap(&left, &right)   // the right-hand column is "correct"
        }

        let items = left.indices.map { row -> TaskItem in
            let correct = left[row], wrong = right[row]
            let centreY = correct.y + correct.height / 2
            let sentence = lines
                .filter { line in
                    abs(line.box.y + line.box.height / 2 - centreY) < max(line.box.height, correct.height) * 1.2
                        && line.box.x + line.box.width <= min(correct.x, wrong.x) + 0.02
                        && contains(zone.box, centreOf: line.box)
                }
                .max(by: { $0.box.x + $0.box.width < $1.box.x + $1.box.width })?.text
            return TaskItem(id: "\(id)-r\(row + 1)", label: sentence, region: correct, secondRegion: wrong)
        }
        return PlayTask(id: id, kind: .trueFalse, prompt: prompt, region: zone.box, items: items, key: nil, confidence: 0.6)
    }

    private static func contains(_ outer: PageRect, centreOf inner: PageRect) -> Bool {
        let cx = inner.x + inner.width / 2
        let cy = inner.y + inner.height / 2
        return cx >= outer.x && cx <= outer.x + outer.width && cy >= outer.y && cy <= outer.y + outer.height
    }
}
