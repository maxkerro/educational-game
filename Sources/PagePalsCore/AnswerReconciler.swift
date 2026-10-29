import Foundation

/// Decides what to do when two methods give an answer key for the same task (calculation, answer page,
/// on-device model). Agreement makes the answer trusted; disagreement removes it so that a grown-up
/// decides. A key typed by a grown-up is never touched here: it always wins in the app.
public enum AnswerReconciler {
    /// Confidence given to an answer that two methods agree on.
    public static let agreed = 0.95
    /// Confidence of a task whose methods disagree.
    public static let disputed = 0.3
    /// A key found by a method with a lower score than this is marked for the grown-up.
    public static let lowScore = 0.5

    /// No key, a fill-in key that misses a field, or a key with a low score that a grown-up has not typed:
    /// the task is shown to the grown-up.
    public static func needsGrownUp(_ task: PlayTask) -> Bool {
        guard let key = task.key else { return true }
        if task.kind == .fillIn && task.items.contains(where: { key.text[$0.id] == nil }) { return true }
        return task.keySource != .parent && task.confidence < lowScore
    }

    /// Where the answers of a task came from, for the grown-up: "Answers: answer page of the book".
    public static func sourceLabel(_ task: PlayTask) -> String? {
        guard task.key != nil, let source = task.keySource else { return nil }
        let name: String
        switch source {
        case .calculated: name = "calculated"
        case .answerPage: name = "answer page of the book"
        case .parent: name = "typed by a grown-up"
        case .model: name = "on-device model"
        }
        var label = "Answers: \(name)"
        if task.confirmed == true && source != .parent { label += " (confirmed by a second method)" }
        if needsGrownUp(task) { label += " (unsure, please check)" }
        return label
    }

    /// "4", "four" and "vier" are the same answer; otherwise answers are compared without case and spaces.
    public static func sameAnswer(_ a: String, _ b: String) -> Bool {
        if let x = NumberWords.value(a), let y = NumberWords.value(b) { return x == y }
        return TaskEvaluator.sameText(a, b)
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
                result.confirmed = true
            } else {
                result.key = nil
                result.keySource = nil
                result.confirmed = nil
                result.confidence = min(first.confidence, disputed)
            }
            return result
        }
    }
}
