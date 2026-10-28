import Foundation

/// Decides what to do when two methods give an answer key for the same task (calculation, answer page,
/// on-device model). Agreement makes the answer trusted; disagreement removes it so that a grown-up
/// decides. A key typed by a grown-up is never touched here: it always wins in the app.
public enum AnswerReconciler {
    /// Confidence given to an answer that two methods agree on.
    public static let agreed = 0.95
    /// Confidence of a task whose methods disagree.
    public static let disputed = 0.3

    /// "4", "four" and "vier" are the same answer; otherwise answers are compared without case and spaces.
    public static func sameAnswer(_ a: String, _ b: String) -> Bool {
        if let x = NumberWords.value(a), let y = NumberWords.value(b) { return x == y }
        return a.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == b.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    public static func sameKey(_ a: AnswerKey, _ b: AnswerKey) -> Bool {
        guard Set(a.text.keys) == Set(b.text.keys) else { return false }
        for (id, value) in a.text {
            guard let other = b.text[id], sameAnswer(value, other) else { return false }
        }
        return a.booleans == b.booleans && a.order == b.order && a.pairs == b.pairs && a.choice == b.choice
    }

    /// Combines two versions of the same task.
    /// - only one has a key: that one is used with its source
    /// - both have the same key: the first is kept and the confidence is raised to `agreed`
    /// - the keys differ: no key, confidence `disputed`, so the task is shown to the grown-up
    public static func merge(_ first: PlayTask, _ second: PlayTask) -> PlayTask {
        switch (first.key, second.key) {
        case (nil, nil):
            return first
        case (_?, nil):
            return first
        case (nil, _?):
            var result = first
            result.key = second.key
            result.keySource = second.keySource
            result.confidence = max(first.confidence, second.confidence)
            return result
        case (let a?, let b?):
            var result = first
            if sameKey(a, b) {
                result.confidence = max(first.confidence, agreed)
            } else {
                result.key = nil
                result.keySource = nil
                result.confidence = min(first.confidence, disputed)
            }
            return result
        }
    }
}
