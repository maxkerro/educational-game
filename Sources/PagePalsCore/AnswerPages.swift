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
        public init(task: Int, answers: [String], group: Int? = nil) {
            self.task = task
            self.answers = answers
            self.group = group
        }
    }

    /// A heading counts as "this is the key" when it names the answers and says nothing else
    /// ("Answers", "Answer key", "Lösungen"). "Answer the questions" is a task, not a key.
    private static let keyWords: Set<String> = [
        "answers", "key", "solutions", "loesungen", "l\u{00F6}sungen", "antworten"
    ]
    private static let fillerWords: Set<String> = ["answer", "l\u{00F6}sung", "loesung"]

    public static func isKeyPage(_ lines: [PageText]) -> Bool {
        let hasHeading = lines.contains { line in
            guard line.box.y < 0.25 else { return false }
            let words = line.text.lowercased()
                .components(separatedBy: CharacterSet.letters.inverted)
                .filter { !$0.isEmpty }
            guard (1...3).contains(words.count), words.allSatisfy({ keyWords.contains($0) || fillerWords.contains($0) }) else { return false }
            return words.contains { keyWords.contains($0) }
        }
        return hasHeading && parse(lines).count >= 3
    }

    /// Lines like "3. 4, 5, 6" or "Task 3: a b c" become entries; a line "Page 10" (or "Seite", "Unit",
    /// "Lektion") starts a group. A task number seen twice in the same group is kept twice, so `apply`
    /// can refuse to guess. Answers are split at commas or semicolons when the line has any, otherwise
    /// at spaces (so a two-word answer needs a comma in the key: "ice cream, 4").
    public static func parse(_ lines: [PageText]) -> [Entry] {
        guard let entryRegex = try? NSRegularExpression(
                pattern: #"^\s*(?:task\s+|aufgabe\s+)?(\d{1,2})\s*[.):]\s*(.+)$"#, options: [.caseInsensitive]),
              let groupRegex = try? NSRegularExpression(
                pattern: #"^\s*(?:page|seite|unit|lektion|kapitel)\s+(\d{1,3})\s*[:.]?\s*$"#, options: [.caseInsensitive])
        else { return [] }
        var entries: [Entry] = []
        var group: Int?
        let ordered = lines.sorted { ($0.box.y, $0.box.x) < ($1.box.y, $1.box.x) }
        for line in ordered {
            let text = line.text
            let range = NSRange(text.startIndex..., in: text)
            if let g = groupRegex.firstMatch(in: text, options: [], range: range),
               let r = Range(g.range(at: 1), in: text), let n = Int(text[r]) {
                group = n
                continue
            }
            guard let match = entryRegex.firstMatch(in: text, options: [], range: range),
                  let numberRange = Range(match.range(at: 1), in: text),
                  let restRange = Range(match.range(at: 2), in: text),
                  let number = Int(text[numberRange]) else { continue }
            let rest = String(text[restRange])
            let separators: CharacterSet = rest.contains(",") || rest.contains(";") ? CharacterSet(charactersIn: ",;") : .whitespaces
            let answers = rest.components(separatedBy: separators)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "."))) }
                .filter { !$0.isEmpty }
            guard !answers.isEmpty else { continue }
            entries.append(Entry(task: number, answers: answers, group: group))
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
    public static func apply(_ entries: [Entry], to task: PlayTask, group: Int? = nil) -> PlayTask {
        guard task.key == nil, let number = taskNumber(of: task.prompt), !task.items.isEmpty else { return task }
        let grouped = entries.contains { $0.group != nil }
        if grouped && group == nil { return task }          // do not guess the page
        let candidates = entries.filter { $0.task == number && (!grouped || $0.group == group) }
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
