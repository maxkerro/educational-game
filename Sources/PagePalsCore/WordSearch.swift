import Foundation

/// Finds the words of a word search in its letter grid, in all 8 directions.
public enum WordSearch {
    public struct Placement: Equatable, Sendable {
        public let row: Int
        public let column: Int
        public let rowStep: Int
        public let columnStep: Int
        public let length: Int

        /// The grid cells (row, column) the word covers, first letter first.
        public var cells: [(row: Int, column: Int)] {
            (0..<length).map { (row + rowStep * $0, column + columnStep * $0) }
        }
    }

    private static let directions: [(Int, Int)] = [(0, 1), (0, -1), (1, 0), (-1, 0), (1, 1), (1, -1), (-1, 1), (-1, -1)]

    /// Every place where the word is written in the grid (rows may have different lengths).
    public static func find(_ word: String, in grid: [[Character]]) -> [Placement] {
        let target = LetterFold.letters(word)
        guard target.count >= 2 else { return [] }
        let cells: [[String]] = grid.map { row in row.map { LetterFold.letters(String($0)).first ?? "" } }
        var found: [Placement] = []
        var seen = Set<String>()
        for r in cells.indices {
            for c in cells[r].indices where cells[r][c] == target[0] {
                for (dr, dc) in directions {
                    var matches = true
                    for k in 1..<target.count {
                        let rr = r + dr * k
                        let cc = c + dc * k
                        guard rr >= 0, rr < cells.count, cc >= 0, cc < cells[rr].count, cells[rr][cc] == target[k] else {
                            matches = false
                            break
                        }
                    }
                    if matches {
                        let place = Placement(row: r, column: c, rowStep: dr, columnStep: dc, length: target.count)
                        // A palindrome (MUM, ANNA) is the same cells read from the other end: count it once.
                        let cellsKey = place.cells.map { "\($0.row),\($0.column)" }.sorted().joined(separator: ";")
                        if seen.insert(cellsKey).inserted { found.append(place) }
                    }
                }
            }
        }
        return found
    }

    /// The place of each word that appears exactly once. Words found twice or not at all are left out,
    /// so the grown-up is asked about them.
    public static func solve(words: [String], grid: [[Character]]) -> [String: Placement] {
        var result: [String: Placement] = [:]
        for word in words {
            let places = find(word, in: grid)
            if places.count == 1 { result[word] = places[0] }
        }
        return result
    }
}
