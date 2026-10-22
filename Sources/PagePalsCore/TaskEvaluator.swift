import Foundation

public struct EvaluationResult: Equatable, Sendable {
    /// Item ids answered correctly.
    public var correct: Set<String>
    /// Item ids answered incorrectly.
    public var incorrect: Set<String>
    /// Item ids with no answer yet.
    public var missing: Set<String>
    /// True when the task has a key and every item is correct.
    public var isComplete: Bool
    /// True when the task has no key; a parent has to confirm.
    public var needsParentCheck: Bool

    public init(
        correct: Set<String> = [],
        incorrect: Set<String> = [],
        missing: Set<String> = [],
        isComplete: Bool = false,
        needsParentCheck: Bool = false
    ) {
        self.correct = correct
        self.incorrect = incorrect
        self.missing = missing
        self.isComplete = isComplete
        self.needsParentCheck = needsParentCheck
    }
}

public enum TaskEvaluator {
    /// Normalises text for comparison: trims, lowercases, removes diacritics and collapses spaces.
    public static func normalize(_ s: String) -> String {
        let folded = s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        return folded
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    /// Same text after normalising; numbers match whatever the spelling ("4", "four", "vier").
    public static func sameText(_ given: String, _ expected: String) -> Bool {
        if normalize(given) == normalize(expected) { return true }
        if let a = NumberWords.value(given), let b = NumberWords.value(expected) { return a == b }
        return false
    }

    public static func evaluate(task: PlayTask, response: TaskResponse) -> EvaluationResult {
        guard let key = task.key else {
            return EvaluationResult(needsParentCheck: true)
        }

        var result = EvaluationResult()

        for (id, expected) in key.text {
            if let given = response.text[id], !normalize(given).isEmpty {
                if sameText(given, expected) { result.correct.insert(id) } else { result.incorrect.insert(id) }
            } else {
                result.missing.insert(id)
            }
        }

        for (id, expected) in key.booleans {
            if let given = response.booleans[id] {
                if given == expected { result.correct.insert(id) } else { result.incorrect.insert(id) }
            } else {
                result.missing.insert(id)
            }
        }

        for (id, expected) in key.order {
            if let given = response.order[id] {
                if given == expected { result.correct.insert(id) } else { result.incorrect.insert(id) }
            } else {
                result.missing.insert(id)
            }
        }

        for (id, expected) in key.pairs {
            if let given = response.pairs[id] {
                if given == expected { result.correct.insert(id) } else { result.incorrect.insert(id) }
            } else {
                result.missing.insert(id)
            }
        }

        if let expectedChoice = key.choice {
            let id = "choice"
            if let given = response.choice {
                if given == expectedChoice { result.correct.insert(id) } else { result.incorrect.insert(id) }
            } else {
                result.missing.insert(id)
            }
        }

        let hasAnyExpectation = !result.correct.isEmpty || !result.incorrect.isEmpty || !result.missing.isEmpty
        result.isComplete = hasAnyExpectation && result.incorrect.isEmpty && result.missing.isEmpty
        return result
    }
}
