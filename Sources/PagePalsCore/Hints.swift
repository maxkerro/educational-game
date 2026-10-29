import Foundation

/// PP-027: hints that help without giving the answer away.
public enum HintLevel: Int, Comparable, Sendable {
    case none, highlight, firstLetter
    public static func < (a: HintLevel, b: HintLevel) -> Bool { a.rawValue < b.rawValue }
}

public struct HintTracker: Equatable, Sendable {
    public private(set) var wrongTries: [String: Int] = [:]
    /// All wrong tries of the task, also for items solved later (used for stars).
    public private(set) var totalWrong = 0

    public init() {}

    public mutating func record(_ itemId: String, correct: Bool) {
        if correct {
            wrongTries[itemId] = nil
        } else {
            wrongTries[itemId, default: 0] += 1
            totalWrong += 1
        }
    }

    /// After two wrong tries the field is highlighted, after three the first letter is shown.
    public func level(_ itemId: String) -> HintLevel {
        let n = wrongTries[itemId] ?? 0
        if n >= 3 { return .firstLetter }
        return n >= 2 ? .highlight : .none
    }

    /// The first letter, e.g. "p…" for "pencil". Nothing for answers of one character or digits only,
    /// where the first character would be the answer.
    public static func hint(for expected: String, level: HintLevel) -> String? {
        guard level == .firstLetter else { return nil }
        let t = expected.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count >= 2, let first = t.first, !t.allSatisfy({ $0.isNumber }) else { return nil }
        return String(first) + "…"
    }
}
