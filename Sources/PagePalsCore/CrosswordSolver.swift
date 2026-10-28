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
        // A candidate is a word in one spelling; a word with ß fits a slot as one letter or as "SS".
        struct Candidate { let word: Int; let letters: [String] }
        let spellings: [[[String]]] = words.map { LetterFold.spellings($0) }
        let candidates: [[Candidate]] = lengths.map { length in
            words.indices.flatMap { w in spellings[w].filter { $0.count == length }.map { Candidate(word: w, letters: $0) } }
        }
        let order = Array(0..<slotCount).sorted { candidates[$0].count < candidates[$1].count }

        var assigned = [Candidate?](repeating: nil, count: slotCount)
        var used = Set<Int>()
        var solutions: [[String]] = []
        var seenSolutions = Set<String>()   // by letters, so "Dog" and "DOG", or the same word listed twice, are one solution

        func fits(slot: Int, candidate: Candidate) -> Bool {
            for c in crossings {
                if c.a == slot, let other = assigned[c.b], candidate.letters[c.aPosition] != other.letters[c.bPosition] { return false }
                if c.b == slot, let other = assigned[c.a], candidate.letters[c.bPosition] != other.letters[c.aPosition] { return false }
            }
            return true
        }

        func search(_ depth: Int) {
            if solutions.count > 1 { return }
            if depth == slotCount {
                let answer = assigned.compactMap { $0 }.map { words[$0.word] }
                let signature = answer.map { LetterFold.letters($0).joined() }.joined(separator: "/")
                if seenSolutions.insert(signature).inserted { solutions.append(answer) }
                return
            }
            let slot = order[depth]
            for candidate in candidates[slot] where !used.contains(candidate.word) && fits(slot: slot, candidate: candidate) {
                assigned[slot] = candidate
                used.insert(candidate.word)
                search(depth + 1)
                assigned[slot] = nil
                used.remove(candidate.word)
            }
        }
        search(0)

        guard solutions.count == 1 else { return nil }
        return solutions[0]
    }
}
