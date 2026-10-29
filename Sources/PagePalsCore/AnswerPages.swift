import Foundation

/// Reads the answer key printed at the back of a workbook ("Answers", "Lösungen") and gives the
/// answers to the tasks, matched by task number. Pure text work, no network.
///
/// Task numbers start again on every page or unit, so a key is usually grouped ("Page 10", "Seite 11",
/// "Unit 3"). Entries remember their group, and a task only gets a key when exactly one entry fits.
public enum AnswerPages {
    public struct Entry: Equatable, Sendable {
        public let task: Int
        public let answers: [String]
        /// The page / unit / Seite number of the group heading above the entry, if the key has such headings.
        public let group: Int?
        /// True when the group heading names a page ("Page 10", "Seite 10", "S. 10"), false for a unit,
        /// chapter, lesson, module or exercise. Only page groups can be matched to a printed page number.
        public let groupIsPage: Bool
        public init(task: Int, answers: [String], group: Int? = nil, groupIsPage: Bool = true) {
            self.task = task
            self.answers = answers
            self.group = group
            self.groupIsPage = groupIsPage
        }
    }

    /// The group of entries that sit under a heading the app could not read (for example "Pages 12-13").
    /// No task is ever given a key from such a group.
    public static let unknownGroup = -1

    /// Words that name the answers. A heading made only of these (plus filler words and an optional
    /// "page 10" / "Unit 1" at the end) is the title of a key: "Answers", "Answer key", "Lösungen zu Seite 10".
    /// "Answer the questions" is a task, not a key.
    private static let keyWords: Set<String> = [
        "answers", "key", "solution", "solutions", "l\u{00F6}sung", "l\u{00F6}sungen", "loesung", "loesungen", "antworten"
    ]
    private static let fillerWords: Set<String> = ["answer", "zu", "to", "for", "of", "der", "des"]
    private static let groupWords: Set<String> = ["page", "pages", "p", "seite", "seiten", "s", "unit", "lektion", "kapitel", "lesson"]
    private static let pageWords: Set<String> = ["page", "pages", "p", "seite", "seiten", "s"]

    private static func tokens(_ text: String) -> [String] {
        text.precomposedStringWithCanonicalMapping.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    /// A key heading that names its page or unit ("Lösungen zu Seite 10", "Answers Unit 1"): that number,
    /// or `unknownGroup` when the page part cannot be read ("Answers Seite 10/11"). nil for other lines.
    private static func keyHeadingGroup(_ text: String) -> (group: Int, isPage: Bool)? {
        let words = tokens(text)
        guard let first = words.first, keyWords.contains(first) || fillerWords.contains(first),
              let i = words.firstIndex(where: { groupWords.contains($0) }),
              i + 1 < words.count, let n = Int(words[i + 1]) else { return nil }
        return (i + 2 == words.count ? n : unknownGroup, pageWords.contains(words[i]))
    }

    private static func isKeyHeading(_ text: String, isTopmost: Bool) -> Bool {
        var words = tokens(text)
        if words.count >= 2, Int(words[words.count - 1]) != nil, groupWords.contains(words[words.count - 2]) {
            words.removeLast(2)
        }
        words.removeAll { Int($0) != nil }      // "Answers 1-20"
        guard (1...3).contains(words.count), words.allSatisfy({ keyWords.contains($0) || fillerWords.contains($0) }) else { return false }
        if words.contains(where: { keyWords.contains($0) }) { return true }
        return isTopmost && words == ["answer"]    // a lone "Answer" counts only as the first line of the page
    }

    public static func isKeyPage(_ lines: [PageText]) -> Bool {
        let top = lines.map { $0.box.y }.min() ?? 0
        let hasHeading = lines.contains { $0.box.y < 0.25 && isKeyHeading($0.text, isTopmost: $0.box.y <= top + 0.001) }
        return hasHeading && parse(lines).count >= 3
    }

    // "S 10" and "p 10" also count: OCR often drops the dot
    private static let groupStart = #"(?:pages?|pp?\.?|seiten?|s\.?|unit|lektion|kapitel|lesson|chapter|ch\.|module|topic|übung|uebung)"#

    /// Lines like "3. 4, 5, 6" or "Task 3: a b c" become entries; a line "Page 10" (or "Seite", "Unit",
    /// "Lektion", "S. 10") starts a group. A heading that cannot be read ("Pages 12-13", "Seite 10/11")
    /// starts the unknown group, so its entries are never used. A task number seen twice in the same
    /// group is kept twice, so `apply` can refuse to guess. Answers are split at commas or semicolons
    /// when the line has any, otherwise at spaces (so a two-word answer needs a comma in the key:
    /// "ice cream, 4").
    ///
    /// Keys are often printed in two or three columns. The numbered lines are split into columns by their
    /// x position and width and each column is read top to bottom, left to right; a heading belongs to the column it
    /// is closest to. A column starts without a group, so entries are never taken over from the column before.
    public static func parse(_ lines: [PageText]) -> [Entry] {
        guard let entryRegex = try? NSRegularExpression(
                pattern: #"^\s*(?:task\s+|aufgabe\s+)?(\d{1,2})\s*[.):]\s*(.+)$"#, options: [.caseInsensitive]),
              let groupRegex = try? NSRegularExpression(
                pattern: "^\\s*" + groupStart + #"\s*(\d{1,3})\s*[:.]?\s*$"#, options: [.caseInsensitive]),
              let pageStart = try? NSRegularExpression(
                pattern: #"^\s*(?:pages?|pp?\.?|seiten?|s\.?)\s*\d"#, options: [.caseInsensitive]),
              let headingLike = try? NSRegularExpression(
                pattern: "^\\s*" + groupStart + #"\s*\d"#, options: [.caseInsensitive]),
              // any other short "word number" line ("Teil 3", "Part 2-3"), except task numbers ("Aufgabe 3")
              let shortHeading = try? NSRegularExpression(
                pattern: #"^\s*(?!task|aufgabe|nr\b|no\b|answers?|key|solutions?|lösung|loesung|antworten)\p{L}+\.?\s*\d[\d\s\-\u2013/]*$"#, options: [.caseInsensitive])
        else { return [] }

        var entryLines: [(x: Double, width: Double, y: Double, task: Int, answers: [String])] = []
        var headings: [(x: Double, y: Double, group: Int, isPage: Bool)] = []
        for line in lines {
            let text = line.text.precomposedStringWithCanonicalMapping
            let range = NSRange(text.startIndex..., in: text)
            if let heading = keyHeadingGroup(text) {
                headings.append((line.box.x, line.box.y, heading.group, heading.isPage))
            } else if let g = groupRegex.firstMatch(in: text, options: [], range: range),
               let r = Range(g.range(at: 1), in: text), let n = Int(text[r]) {
                headings.append((line.box.x, line.box.y, n, pageStart.firstMatch(in: text, options: [], range: range) != nil))
            } else if headingLike.firstMatch(in: text, options: [], range: range) != nil
                        || shortHeading.firstMatch(in: text, options: [], range: range) != nil {
                headings.append((line.box.x, line.box.y, unknownGroup, false))
            } else if let match = entryRegex.firstMatch(in: text, options: [], range: range),
                      let numberRange = Range(match.range(at: 1), in: text),
                      let restRange = Range(match.range(at: 2), in: text),
                      let number = Int(text[numberRange]) {
                let rest = String(text[restRange])
                let separators: CharacterSet = rest.contains(",") || rest.contains(";") ? CharacterSet(charactersIn: ",;") : .whitespaces
                let answers = rest.components(separatedBy: separators)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "."))) }
                    .filter { !$0.isEmpty }
                if !answers.isEmpty { entryLines.append((line.box.x, line.box.width, line.box.y, number, answers)) }
            }
        }
        guard !entryLines.isEmpty else { return [] }

        // Columns of numbered lines: a line starts a new column when it begins to the right of every box
        // of the current column, so narrow columns that sit close together are still told apart.
        var columns: [[Int]] = []                       // indices into entryLines
        var rightEdge = 0.0
        for index in entryLines.indices.sorted(by: { entryLines[$0].x < entryLines[$1].x }) {
            if !columns.isEmpty, entryLines[index].x <= rightEdge {
                columns[columns.count - 1].append(index)
                rightEdge = max(rightEdge, entryLines[index].x + entryLines[index].width)
            } else {
                columns.append([index])
                rightEdge = entryLines[index].x + entryLines[index].width
            }
        }
        func distance(_ x: Double, to column: [Int]) -> Double {
            let xs = column.map { entryLines[$0].x }
            guard let low = xs.min(), let high = xs.max() else { return .infinity }
            return x < low ? low - x : (x > high ? x - high : 0)
        }

        var entries: [Entry] = []
        for (c, column) in columns.enumerated() {
            let mine = headings.filter { heading in
                let nearest = columns.indices.min { distance(heading.x, to: columns[$0]) < distance(heading.x, to: columns[$1]) } ?? 0
                return nearest == c
            }
            enum Row { case heading(Int, Bool), entry(Int) }
            var rows: [(y: Double, row: Row)] = mine.map { ($0.y, Row.heading($0.group, $0.isPage)) }
            rows += column.map { (entryLines[$0].y, Row.entry($0)) }
            var group: Int?
            var isPage = true
            for item in rows.sorted(by: { $0.y < $1.y }) {
                switch item.row {
                case .heading(let g, let p):
                    group = g
                    isPage = p
                case .entry(let i):
                    entries.append(Entry(task: entryLines[i].task, answers: entryLines[i].answers, group: group, groupIsPage: group == nil || isPage))
                }
            }
        }
        return entries
    }

    /// The number a task starts with: "3. Count and write." -> 3.
    public static func taskNumber(of prompt: String) -> Int? {
        let digits = prompt.trimmingCharacters(in: .whitespaces).prefix { $0.isASCII && $0.isNumber }
        return digits.isEmpty ? nil : Int(digits)
    }

    /// Gives a task its key from the answer page when exactly one entry fits and it has one answer per
    /// item, in the order of `task.items` (reading order). `group` is the printed page (or unit) number of
    /// the task; it is needed when the key has page headings. Tasks that already have a key are left alone.
    /// With `pageGroupsOnly`, `group` is a printed page number and unit / chapter groups are never matched to it.
    public static func apply(_ entries: [Entry], to task: PlayTask, group: Int? = nil, pageGroupsOnly: Bool = false) -> PlayTask {
        guard task.key == nil, let number = taskNumber(of: task.prompt), !task.items.isEmpty else { return task }
        let grouped = entries.contains { $0.group != nil }
        if grouped && (group == nil || group == unknownGroup) { return task }   // do not guess the page
        if group != nil && !grouped { return task }          // a key without page headings cannot be placed on a page
        let candidates = entries.filter { $0.task == number && (!grouped || ($0.group == group && (!pageGroupsOnly || $0.groupIsPage))) }
        guard candidates.count == 1, let entry = candidates.first,
              entry.answers.count == task.items.count else { return task }

        var key = AnswerKey()
        switch task.kind {
        case .fillIn:
            for (item, answer) in zip(task.items, entry.answers) { key.text[item.id] = answer }
        case .numberInOrder:
            for (item, answer) in zip(task.items, entry.answers) {
                guard let n = NumberWords.value(answer) else { return task }
                key.order[item.id] = n
            }
        default:
            return task
        }
        var result = task
        result.key = key
        result.keySource = .answerPage
        result.confidence = max(task.confidence, 0.9)
        return result
    }
}
