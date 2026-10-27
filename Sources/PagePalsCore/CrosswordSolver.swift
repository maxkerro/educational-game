import Foundation

/// Fits the printed word list into a crossword by length and crossing letters.
/// The grid itself (slot lengths and where slots cross) comes from the page recognition.
public enum CrosswordSolver {
    /// Letter `aPosition` of slot `a` is the same cell as letter `bPosition` of slot `b` (0-based).
    public struct Crossing: Equatable, Sendable {
        public let a: Int
        public let aPosition: Int
        public let b: Int
        public let bPosition: Int
        public init(a: Int, aPosition: Int, b: Int, bPosition: Int) {
            self.a = a
            self.aPosition = aPosition
            self.b = b
            self.bPosition = bPosition
        }
    }

    /// One word per slot (same order as `lengths`, spelled as in `words`), or nil when there is no
    /// solution or more than one, so the grown-up is asked instead of the app guessing.
    public static func solve(lengths: [Int], crossings: [Crossing], words: [String]) -> [String]? {
        let slotCount = lengths.count
        guard slotCount > 0 else { return nil }
        for c in crossings {
            guard (0..<slotCount).contains(c.a), (0..<slotCount).contains(c.b),
                  (0..<lengths[c.a]).contains(c.aPosition), (0..<lengths[c.b]).contains(c.bPosition) else { return nil }
        }
        let letters: [[String]] = words.map { LetterFold.letters($0) }
        let candidates: [[Int]] = lengths.map { length in letters.indices.filter { letters[$0].count == length } }
        let order = Array(0..<slotCount).sorted { candidates[$0].count < candidates[$1].count }

        var assigned = [Int?](repeating: nil, count: slotCount)
        var used = Set<Int>()
        var solutions: [[String]] = []   // distinct answers; the same word listed twice is not a second solution

        func fits(slot: Int, word: Int) -> Bool {
            for c in crossings {
                if c.a == slot, let other = assigned[c.b], letters[word][c.aPosition] != letters[other][c.bPosition] { return false }
                if c.b == slot, let other = assigned[c.a], letters[word][c.bPosition] != letters[other][c.aPosition] { return false }
            }
            return true
        }

        func search(_ depth: Int) {
            if solutions.count > 1 { return }
            if depth == slotCount {
                let answer = assigned.compactMap { $0 }.map { words[$0] }
                if !solutions.contains(answer) { solutions.append(answer) }
                return
            }
            let slot = order[depth]
            for word in candidates[slot] where !used.contains(word) && fits(slot: slot, word: word) {
                assigned[slot] = word
                used.insert(word)
                search(depth + 1)
                assigned[slot] = nil
                used.remove(word)
            }
        }
        search(0)

        guard solutions.count == 1 else { return nil }
        return solutions[0]
    }
}
