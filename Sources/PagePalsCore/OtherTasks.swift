import Foundation

/// Tasks that are not numbers, sums or ticks: choose one answer (PP-021), draw lines (PP-020) and put in order (PP-025).
/// Their answers are not known from the page; a grown-up does the task once and the result is kept as the key.
public enum OtherTasks {
    /// Builds the task the header asks for, or `nil` when the page does not look like it.
    public static func build(id: String, prompt: String, zone: TaskZone, lines: [PageText], pictures: [PageRect]) -> PlayTask? {
        switch TaskTypeClassifier.kind(forHeader: zone.title) {
        case .multipleChoice?: return choice(id: id, prompt: prompt, zone: zone, lines: lines)
        case .matching?: return matching(id: id, prompt: prompt, zone: zone, lines: lines, pictures: pictures)
        case .ordering?: return ordering(id: id, prompt: prompt, zone: zone, lines: lines)
        default: return nil
        }
    }

    // MARK: - Lines of the task

    static func wordCount(_ text: String) -> Int { text.split(whereSeparator: { $0.isWhitespace }).count }

    private static func inside(_ zone: PageRect, _ box: PageRect) -> Bool {
        let cx = box.x + box.width / 2, cy = box.y + box.height / 2
        return cx >= zone.x && cx <= zone.x + zone.width && cy >= zone.y && cy <= zone.y + zone.height
    }

    /// The text lines of a task without its header and without lone numbers (page numbers).
    static func bodyLines(_ zone: TaskZone, _ lines: [PageText]) -> [PageText] {
        lines
            .filter { inside(zone.box, $0.box) }
            .filter { TaskBuilder.headerParts($0.text) == nil }
            .filter { !$0.text.trimmingCharacters(in: .whitespaces).allSatisfy { $0.isNumber } }
            .sorted { ($0.box.y, $0.box.x) < ($1.box.y, $1.box.x) }
    }

    // MARK: - Choose one

    private static let marker = try? NSRegularExpression(pattern: #"(?<![\p{L}\d])(?:\(?[a-f]\)|[A-F][.)])\s*"#)

    /// Options written with letters on one line ("A) big B) red") or one per line ("A) yellow").
    /// The part before the first marker is the question and is not an option.
    static func markedOptions(_ line: PageText) -> [(label: String, box: PageRect)] {
        guard let marker else { return [] }
        let text = line.text
        let whole = NSRange(text.startIndex..., in: text)
        let found = marker.matches(in: text, range: whole)
        guard !found.isEmpty else { return [] }
        let total = Double(max(1, whole.length))
        var result: [(String, PageRect)] = []
        for (i, m) in found.enumerated() {
            let start = m.range.location + m.range.length
            let end = i + 1 < found.count ? found[i + 1].range.location : whole.length
            guard end > start, let r = Range(NSRange(location: start, length: end - start), in: text) else { continue }
            let label = String(text[r]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !label.isEmpty else { continue }
            let x = line.box.x + line.box.width * Double(m.range.location) / total
            let w = line.box.width * Double(end - m.range.location) / total
            result.append((label, PageRect(x: x, y: line.box.y, width: w, height: line.box.height)))
        }
        return result
    }

    static func choice(id: String, prompt: String, zone: TaskZone, lines: [PageText]) -> PlayTask? {
        let body = bodyLines(zone, lines)
        var options: [(label: String, box: PageRect)] = []
        for line in body { options += markedOptions(line) }
        if options.isEmpty {
            // no letters: short lines are the options
            guard (2...6).contains(body.count), body.allSatisfy({ wordCount($0.text) <= 4 }) else { return nil }
            options = body.map { ($0.text.trimmingCharacters(in: .whitespaces), $0.box) }
        }
        guard (2...6).contains(options.count) else { return nil }
        let items = options.enumerated().map { TaskItem(id: "\(id)-o\($0.offset + 1)", label: $0.element.label, region: $0.element.box) }
        return PlayTask(id: id, kind: .multipleChoice, prompt: prompt, region: zone.box, items: items, key: nil, confidence: 0.5)
    }

    // MARK: - Draw lines

    private static func overlaps(_ a: PageRect, _ b: PageRect) -> Bool {
        a.x < b.x + b.width && b.x < a.x + a.width && a.y < b.y + b.height && b.y < a.y + a.height
    }

    /// Pictures and short words: as many words as pictures, words not on a picture. Lines start at a picture.
    static func matching(id: String, prompt: String, zone: TaskZone, lines: [PageText], pictures: [PageRect]) -> PlayTask? {
        let pics = pictures.filter { inside(zone.box, $0) }.sorted { ($0.y, $0.x) < ($1.y, $1.x) }
        let words = bodyLines(zone, lines).filter { line in
            wordCount(line.text) <= 3 && !pics.contains { overlaps($0, line.box) }
        }
        guard pics.count >= 2, pics.count <= 8, words.count == pics.count else { return nil }
        var items = pics.enumerated().map { TaskItem(id: "\(id)-a\($0.offset + 1)", region: $0.element, isTarget: false) }
        items += words.enumerated().map {
            TaskItem(id: "\(id)-b\($0.offset + 1)", label: $0.element.text.trimmingCharacters(in: .whitespaces), region: $0.element.box, isTarget: true)
        }
        return PlayTask(id: id, kind: .matching, prompt: prompt, region: zone.box, items: items, key: nil, confidence: 0.4)
    }

    // MARK: - Put in order

    /// Sentences or words as printed (scrambled); the right order is set by a grown-up.
    static func ordering(id: String, prompt: String, zone: TaskZone, lines: [PageText]) -> PlayTask? {
        let body = bodyLines(zone, lines)
        guard (3...8).contains(body.count), body.allSatisfy({ wordCount($0.text) >= 2 }) else { return nil }
        let items = body.enumerated().map {
            TaskItem(id: "\(id)-s\($0.offset + 1)", label: $0.element.text.trimmingCharacters(in: .whitespaces), region: $0.element.box)
        }
        return PlayTask(id: id, kind: .ordering, prompt: prompt, region: zone.box, items: items, key: nil, confidence: 0.4)
    }
}
