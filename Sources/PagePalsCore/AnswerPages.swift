import Foundation

/// Reads the answer key printed at the back of a workbook ("Answers", "Lösungen") and gives the
/// answers to the tasks, matched by task number. Pure text work, no network.
public enum AnswerPages {
    public struct Entry: Equatable, Sendable {
        public let task: Int
        public let answers: [String]
        public init(task: Int, answers: [String]) {
            self.task = task
            self.answers = answers
        }
    }

    private static let headingWords: Set<String> = [
        "answers", "answer", "key", "solutions", "loesungen", "l\u{00F6}sungen", "loesung", "l\u{00F6}sung", "antworten"
    ]

    /// A page is an answer page when a short heading near the top names the answers and at least
    /// three lines look like "1. answer".
    public static func isKeyPage(_ lines: [PageText]) -> Bool {
        let hasHeading = lines.contains { line in
            guard line.box.y < 0.25 else { return false }
            let words = line.text.lowercased()
                .components(separatedBy: CharacterSet.letters.inverted)
                .filter { !$0.isEmpty }
            return words.count <= 4 && words.contains { headingWords.contains($0) }
        }
        return hasHeading && parse(lines).count >= 3
    }

    /// Lines like "3. 4, 5, 6" or "Task 3: a b c" become entries. A task number seen twice keeps the first.
    public static func parse(_ lines: [PageText]) -> [Entry] {
        guard let regex = try? NSRegularExpression(
            pattern: #"^\s*(?:task\s+|aufgabe\s+)?(\d{1,2})\s*[.):]\s*(.+)$"#,
            options: [.caseInsensitive]) else { return [] }
        var entries: [Entry] = []
        var seen = Set<Int>()
        let ordered = lines.sorted { ($0.box.y, $0.box.x) < ($1.box.y, $1.box.x) }
        for line in ordered {
            let text = line.text
            let range = NSRange(text.startIndex..., in: text)
            guard let match = regex.firstMatch(in: text, options: [], range: range),
                  let numberRange = Range(match.range(at: 1), in: text),
                  let restRange = Range(match.range(at: 2), in: text),
                  let number = Int(text[numberRange]) else { continue }
            let rest = String(text[restRange])
            let separators: CharacterSet = rest.contains(",") || rest.contains(";") ? CharacterSet(charactersIn: ",;") : .whitespaces
            let answers = rest.components(separatedBy: separators)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "."))) }
                .filter { !$0.isEmpty }
            guard !answers.isEmpty, !seen.contains(number) else { continue }
            seen.insert(number)
            entries.append(Entry(task: number, answers: answers))
        }
        return entries
    }

    /// The number a task starts with: "3. Count and write." -> 3.
    public static func taskNumber(of prompt: String) -> Int? {
        let digits = prompt.trimmingCharacters(in: .whitespaces).prefix { $0.isASCII && $0.isNumber }
        return digits.isEmpty ? nil : Int(digits)
    }

    /// Gives a task its key from the answer page when the numbers match and there is one answer per item,
    /// in the order of `task.items` (reading order). Tasks that already have a key are left alone.
    public static func apply(_ entries: [Entry], to task: PlayTask) -> PlayTask {
        guard task.key == nil, let number = taskNumber(of: task.prompt),
              let entry = entries.first(where: { $0.task == number }),
              entry.answers.count == task.items.count, !task.items.isEmpty else { return task }

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
