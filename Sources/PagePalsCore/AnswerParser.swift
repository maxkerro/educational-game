import Foundation

public enum AnswerParseError: Error, Equatable, Sendable {
    case notJSON
    case incomplete
}

/// Reads the AI's reply: a small JSON object that maps a letter (A, B, C ...) to an answer.
/// Letters follow the order of the task's items. Text around the JSON is ignored.
public enum AnswerParser {
    public static func letter(_ index: Int) -> String {
        String(UnicodeScalar(UInt8(65 + index % 26)))
    }

    public static func parse(reply: String, kind: TaskKind, items: [TaskItem]) throws -> AnswerKey {
        guard let start = reply.firstIndex(of: "{"), let end = reply.lastIndex(of: "}"), start < end,
              let object = try? JSONSerialization.jsonObject(with: Data(reply[start...end].utf8)) as? [String: Any] else {
            throw AnswerParseError.notJSON
        }
        var key = AnswerKey()
        for (index, item) in items.enumerated() {
            guard let raw = object[letter(index)] else { throw AnswerParseError.incomplete }
            if kind == .numberInOrder {
                if let n = raw as? Int {
                    key.order[item.id] = n
                } else if let s = raw as? String, let n = Int(s.trimmingCharacters(in: .whitespaces)) {
                    key.order[item.id] = n
                } else {
                    throw AnswerParseError.incomplete
                }
            } else {
                let text = ((raw as? String) ?? String(describing: raw)).trimmingCharacters(in: .whitespaces)
                if text.isEmpty { throw AnswerParseError.incomplete }
                key.text[item.id] = text
            }
        }
        return key
    }
}
