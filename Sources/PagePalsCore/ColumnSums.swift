import Foundation

/// Sums written in a column the way children write them on paper:
///
///        23
///      + 45
///      ----
///
/// The lines are stacked, right-aligned, and every line after the first starts with a sign.
/// Each stack becomes one expression ("23 + 45 =") for `MathSolver`.
public enum ColumnSums {
    public struct Sum: Equatable, Sendable {
        /// For example "23 + 45 =".
        public let expression: String
        /// The box around all lines of the stack.
        public let box: PageRect
    }

    private static let signs: [Character: String] = [
        "+": "+", "-": "-", "\u{2013}": "-", "\u{2212}": "-", "\u{00D7}": "x", "x": "x", "X": "x", "*": "x", "\u{00F7}": "\u{00F7}"
    ]

    /// A number with an optional sign in front ("45", "+ 45", "\u{2212}7").
    private static func operand(_ text: String) -> (sign: String?, digits: String)? {
        var t = text.trimmingCharacters(in: .whitespaces)
        var sign: String?
        if let first = t.first, let known = signs[first] {
            sign = known
            t = String(t.dropFirst()).trimmingCharacters(in: .whitespaces)
        }
        guard !t.isEmpty, t.count <= 6, t.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        return (sign, t)
    }

    public static func find(_ lines: [PageText]) -> [Sum] {
        let sorted = lines.sorted { $0.box.y < $1.box.y }
        var used = Set<Int>()
        var sums: [Sum] = []

        for start in sorted.indices where !used.contains(start) {
            guard let first = operand(sorted[start].text), first.sign == nil else { continue }
            var members = [start]
            var numbers = [first.digits]
            var signsFound: [String] = []
            var last = sorted[start]

            while signsFound.count < 4 {
                var best: (index: Int, sign: String, digits: String)?
                var bestGap = Double.infinity
                for j in sorted.indices where !used.contains(j) && !members.contains(j) {
                    let next = sorted[j]
                    guard let parsed = operand(next.text), let sign = parsed.sign else { continue }
                    let gap = next.box.y - (last.box.y + last.box.height)
                    let rightEdges = abs((next.box.x + next.box.width) - (last.box.x + last.box.width))
                    guard gap > -0.005, gap < max(last.box.height, next.box.height) * 2.0, rightEdges < 0.03, gap < bestGap else { continue }
                    best = (j, sign, parsed.digits)
                    bestGap = gap
                }
                guard let found = best else { break }
                members.append(found.index)
                signsFound.append(found.sign)
                numbers.append(found.digits)
                last = sorted[found.index]
            }
            guard !signsFound.isEmpty else { continue }

            var expression = numbers[0]
            for (index, sign) in signsFound.enumerated() { expression += " \(sign) \(numbers[index + 1])" }
            expression += " ="

            let boxes = members.map { sorted[$0].box }
            let minX = boxes.map { $0.x }.min() ?? 0
            let minY = boxes.map { $0.y }.min() ?? 0
            let maxX = boxes.map { $0.x + $0.width }.max() ?? 0
            let maxY = boxes.map { $0.y + $0.height }.max() ?? 0
            used.formUnion(members)
            sums.append(Sum(expression: expression, box: PageRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)))
        }
        return sums
    }
}
