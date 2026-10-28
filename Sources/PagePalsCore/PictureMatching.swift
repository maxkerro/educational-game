import Foundation

/// Turns the scores of an image-text model into answers, so the model itself can be swapped
/// (a Core ML CLIP model, an MLX vision-language model). The model is asked how well each picture fits each
/// word; this file decides which word belongs to which picture and how sure that is.
public enum PictureMatching {
    public struct Assignment: Equatable, Sendable {
        /// For each picture, the index of its word.
        public let wordForPicture: [Int]
        /// 0...1. Based on the gap between the best and the second-best way to pair pictures with words.
        public let confidence: Double
    }

    /// The best one-to-one pairing of pictures (rows) and words (columns).
    /// - Parameters:
    ///   - scores: `scores[picture][word]`, higher is better (for example cosine similarity)
    ///   - minimumGap: the best pairing must beat the second best by at least this total score, otherwise nil
    /// - Returns: nil when the matrix is not square, is empty, or no pairing is clearly better than the rest.
    public static func assign(scores: [[Double]], minimumGap: Double = 0.02) -> Assignment? {
        let n = scores.count
        guard n >= 1, n <= 12, scores.allSatisfy({ $0.count == n }) else { return nil }

        if n <= 8 { return exhaustive(scores, n, minimumGap) }
        return greedy(scores, n, minimumGap)
    }

    private static func confidence(forGap gap: Double) -> Double { min(1.0, max(0.0, gap / 0.1)) }

    private static func exhaustive(_ scores: [[Double]], _ n: Int, _ minimumGap: Double) -> Assignment? {
        var best = -Double.infinity
        var second = -Double.infinity
        var bestPick = [Int](repeating: 0, count: n)
        var current = [Int](repeating: 0, count: n)

        func walk(_ row: Int, _ used: Int, _ total: Double) {
            if row == n {
                if total > best {
                    second = best
                    best = total
                    bestPick = current
                } else if total > second {
                    second = total
                }
                return
            }
            for word in 0..<n where used & (1 << word) == 0 {
                current[row] = word
                walk(row + 1, used | (1 << word), total + scores[row][word])
            }
        }
        walk(0, 0, 0)

        // one picture and one word: there is nothing to compare, so the score itself must be clear
        let gap = n == 1 ? best : best - second
        guard gap >= minimumGap else { return nil }
        return Assignment(wordForPicture: bestPick, confidence: confidence(forGap: gap))
    }

    /// For larger tasks: take the best score first; every pick must beat the runner-up in its row and column.
    private static func greedy(_ scores: [[Double]], _ n: Int, _ minimumGap: Double) -> Assignment? {
        var pairs: [(picture: Int, word: Int, score: Double)] = []
        for p in 0..<n { for w in 0..<n { pairs.append((p, w, scores[p][w])) } }
        pairs.sort { $0.score > $1.score }

        var pictureDone = Set<Int>()
        var wordDone = Set<Int>()
        var pick = [Int](repeating: -1, count: n)
        var smallestGap = Double.infinity
        for pair in pairs where !pictureDone.contains(pair.picture) && !wordDone.contains(pair.word) {
            let rowRunnerUp = (0..<n).filter { $0 != pair.word && !wordDone.contains($0) }.map { scores[pair.picture][$0] }.max()
            let columnRunnerUp = (0..<n).filter { $0 != pair.picture && !pictureDone.contains($0) }.map { scores[$0][pair.word] }.max()
            let runnerUp = max(rowRunnerUp ?? -Double.infinity, columnRunnerUp ?? -Double.infinity)
            let gap = runnerUp == -Double.infinity ? pair.score : pair.score - runnerUp
            smallestGap = min(smallestGap, gap)
            pick[pair.picture] = pair.word
            pictureDone.insert(pair.picture)
            wordDone.insert(pair.word)
        }
        guard !pick.contains(-1), smallestGap >= minimumGap else { return nil }
        return Assignment(wordForPicture: pick, confidence: confidence(forGap: smallestGap))
    }

    /// "Number the pictures": circle `i` sits at picture `i`; its number is the position (from 1) of the picture's word
    /// in the printed word list.
    public static func numberKey(circles: [TaskItem], assignment: Assignment) -> AnswerKey? {
        guard circles.count == assignment.wordForPicture.count else { return nil }
        var key = AnswerKey()
        for (index, circle) in circles.enumerated() { key.order[circle.id] = assignment.wordForPicture[index] + 1 }
        return key
    }
}

/// Reads "There are two ladybirds." / "Es gibt drei Marienkäfer." and judges it against a counted number.
public enum CountStatement {
    /// The number the sentence states ("There is one", "two", "3", "ein", "a ladybird"); nil when it states none.
    public static func stated(_ sentence: String) -> Int? {
        let words = sentence.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        for word in words {
            if let n = NumberWords.value(word) { return n }
        }
        if words.starts(with: ["there", "is", "a"]) || words.starts(with: ["there", "is", "an"]) { return 1 }
        return nil
    }

    /// True when the sentence states exactly the counted number; nil when either is unknown.
    public static func isCorrect(_ sentence: String, counted: Int?) -> Bool? {
        guard let counted, let said = stated(sentence) else { return nil }
        return said == counted
    }

    /// The key of a tick task whose rows are counting sentences. `counts[i]` is the number counted for row `i`
    /// (nil if the counter was unsure). Returns nil unless every row could be judged.
    public static func tickKey(rows: [TaskItem], counts: [Int?]) -> AnswerKey? {
        guard rows.count == counts.count else { return nil }
        var key = AnswerKey()
        for (row, count) in zip(rows, counts) {
            guard let sentence = row.label, let verdict = isCorrect(sentence, counted: count) else { return nil }
            key.booleans[row.id] = verdict
        }
        return key
    }
}

/// Where optional on-device models live. The app works without them: answers are then calculated, read from the
/// answer pages, or typed once by a grown-up.
public enum OfflineModels {
    /// `~/Library/Application Support/PagePals/Models`
    public static var folder: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory())
        return base.appendingPathComponent("PagePals", isDirectory: true).appendingPathComponent("Models", isDirectory: true)
    }

    /// The file or folder of a model that was put in place by hand, or nil when it is not installed.
    public static func locate(_ name: String, in folder: URL = OfflineModels.folder) -> URL? {
        let url = folder.appendingPathComponent(name)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}

/// Anything that can say how well a picture fits a word (a Core ML CLIP model, an MLX vision-language model).
/// Implementations live outside `PagePalsCore` because they need the model frameworks.
public protocol PictureScoring {
    /// `result[picture][word]`, higher is better. Throws when the model is missing or fails.
    func scores(pictureFiles: [URL], words: [String]) throws -> [[Double]]
}
