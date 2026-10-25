import Foundation

/// Solves the maths lines of a workbook without any network or model.
///
/// Understood (digits or number words 0...100, English or German):
/// - sums, differences, products and quotients: `3 + 4 =`, `six - two =`, `6 x 7 =`, `12 ÷ 4 =`
///   (signs only; words such as "plus" are not read)
/// - several operations with the usual precedence: `2 + 3 x 4 =`
/// - a missing number: `3 + ___ = 7`, `___ - 2 = 5`, `8 = 5 + _`
/// - comparing: `5 _ 3` or `2 + 2 _ 5` gives `>` `<` or `=`
/// - a number sequence with one gap: `2, 4, _, 8`
/// The answer is written like the question: digits for digits, words for words (German for German words).
/// Anything else, and any negative or non-whole result, gives nil.
public enum MathSolver {
    enum Token: Equatable {
        case num(Int)
        case op(Character)   // + - * /
        case eq
        case comma
        case blank
    }

    struct Parsed {
        var tokens: [Token] = []
        var usesWords = false
        var usesGerman = false
    }

    private static let blankMarks: Set<Character> = ["_", "\u{25A1}", "?", "\u{2026}"]
    private static let searchLimit = 1000

    public static func solve(_ text: String) -> String? {
        guard let parsed = tokenize(text) else { return nil }
        let tokens = parsed.tokens
        let blanks = tokens.filter { $0 == .blank }.count
        let equals = tokens.filter { $0 == .eq }.count

        if equals == 1 {
            guard let at = tokens.firstIndex(of: .eq) else { return nil }
            let left = Array(tokens[..<at])
            let right = Array(tokens[(at + 1)...])
            if blanks == 0 {
                guard right.isEmpty, !left.isEmpty, let v = evaluate(left) else { return nil }
                return format(v, parsed)
            }
            guard blanks == 1 else { return nil }
            if left.contains(.blank) {
                guard !right.isEmpty, let target = evaluate(right), let n = solveBlank(left, target: target) else { return nil }
                return format(n, parsed)
            }
            if right == [.blank] {
                guard let v = evaluate(left) else { return nil }
                return format(v, parsed)
            }
            guard right.contains(.blank), !left.isEmpty, let target = evaluate(left),
                  let n = solveBlank(right, target: target) else { return nil }
            return format(n, parsed)
        }

        guard equals == 0, blanks == 1 else { return nil }
        if tokens.contains(.comma) { return sequenceGap(tokens).map { format($0, parsed) } }
        return compare(tokens)
    }

    // MARK: - Reading the text

    static func tokenize(_ text: String) -> Parsed? {
        var p = Parsed()
        let c = Array(text)
        var i = 0
        while i < c.count {
            let ch = c[i]
            if ch.isWhitespace { i += 1; continue }
            if ch.isASCII && ch.isNumber {
                var j = i
                while j < c.count, c[j].isASCII, c[j].isNumber { j += 1 }
                guard j - i <= 6, let n = Int(String(c[i..<j])) else { return nil }
                p.tokens.append(.num(n))
                i = j
            } else if ch.isLetter {
                var j = i
                while j < c.count, c[j].isLetter { j += 1 }
                var word = String(c[i..<j])
                // "twenty-one": a hyphen between two letters joins them when the result is a number word
                while j + 1 < c.count, c[j] == "-", c[j + 1].isLetter {
                    var k = j + 1
                    while k < c.count, c[k].isLetter { k += 1 }
                    let joined = word + "-" + String(c[(j + 1)..<k])
                    guard NumberWords.value(joined) != nil else { break }
                    word = joined
                    j = k
                }
                if word.lowercased() == "x" {
                    p.tokens.append(.op("*"))
                } else if let v = NumberWords.value(word) {
                    p.tokens.append(.num(v))
                    p.usesWords = true
                    if NumberWords.isGerman(word) { p.usesGerman = true }
                } else {
                    return nil
                }
                i = j
            } else if blankMarks.contains(ch) || (ch == "." && i + 1 < c.count && c[i + 1] == ".") {
                var j = i
                while j < c.count, blankMarks.contains(c[j]) || c[j] == "." || c[j].isWhitespace && j + 1 < c.count && (blankMarks.contains(c[j + 1]) || c[j + 1] == ".") { j += 1 }
                p.tokens.append(.blank)
                i = j
            } else {
                switch ch {
                case "+": p.tokens.append(.op("+"))
                case "-", "\u{2013}", "\u{2014}", "\u{2212}": p.tokens.append(.op("-"))
                case "*", "\u{00D7}", "\u{22C5}": p.tokens.append(.op("*"))
                case "\u{00F7}": p.tokens.append(.op("/"))
                case "=": p.tokens.append(.eq)
                case ",": p.tokens.append(.comma)
                default: break   // a stray full stop or similar is ignored
                }
                i += 1
            }
        }
        return p.tokens.isEmpty ? nil : p
    }

    // MARK: - Calculating

    /// number (op number)*, with * and / before + and -; nil when malformed, not whole, or negative.
    static func evaluate(_ tokens: [Token]) -> Int? {
        guard tokens.count % 2 == 1 else { return nil }
        var numbers: [Int] = []
        var ops: [Character] = []
        for (index, token) in tokens.enumerated() {
            switch (index % 2, token) {
            case (0, .num(let n)): numbers.append(n)
            case (1, .op(let o)): ops.append(o)
            default: return nil
            }
        }

        var terms: [Int] = [numbers[0]]
        var addOps: [Character] = []
        for (i, o) in ops.enumerated() {
            let n = numbers[i + 1]
            switch o {
            case "*":
                guard abs(terms[terms.count - 1]) < 1_000_000_000_000 else { return nil }
                terms[terms.count - 1] *= n
            case "/":
                guard n != 0, terms[terms.count - 1] % n == 0 else { return nil }
                terms[terms.count - 1] /= n
            default:
                addOps.append(o)
                terms.append(n)
            }
        }
        var total = terms[0]
        for (i, o) in addOps.enumerated() { total += o == "+" ? terms[i + 1] : -terms[i + 1] }
        return total >= 0 ? total : nil
    }

    /// The one number that makes the expression (with one blank) equal to `target`; nil when none or several.
    static func solveBlank(_ tokens: [Token], target: Int) -> Int? {
        guard let at = tokens.firstIndex(of: .blank) else { return nil }
        var found: Int?
        for n in 0...searchLimit {
            var filled = tokens
            filled[at] = .num(n)
            if evaluate(filled) == target {
                if found != nil { return nil }
                found = n
            }
        }
        return found
    }

    /// `a _ b` -> ">", "<" or "=" when both sides can be calculated.
    static func compare(_ tokens: [Token]) -> String? {
        guard let at = tokens.firstIndex(of: .blank), at > 0, at < tokens.count - 1,
              let a = evaluate(Array(tokens[..<at])), let b = evaluate(Array(tokens[(at + 1)...])) else { return nil }
        return a > b ? ">" : (a < b ? "<" : "=")
    }

    /// `2, 4, _, 8` -> 6. Needs two numbers and a constant step.
    static func sequenceGap(_ tokens: [Token]) -> Int? {
        var slots: [Int?] = []
        var expectItem = true
        for token in tokens {
            switch (expectItem, token) {
            case (true, .num(let n)): slots.append(n); expectItem = false
            case (true, .blank): slots.append(nil); expectItem = false
            case (false, .comma): expectItem = true
            default: return nil
            }
        }
        guard slots.count >= 3, !expectItem, let gap = slots.firstIndex(where: { $0 == nil }) else { return nil }
        var known: [(Int, Int)] = []
        for (index, slot) in slots.enumerated() { if let value = slot { known.append((index, value)) } }
        guard known.count >= 2 else { return nil }
        let (i0, v0) = known[0]
        let (i1, v1) = known[1]
        guard (v1 - v0) % (i1 - i0) == 0 else { return nil }
        let step = (v1 - v0) / (i1 - i0)
        for (i, v) in known where v != v0 + step * (i - i0) { return nil }
        let answer = v0 + step * (gap - i0)
        return answer >= 0 ? answer : nil
    }

    private static func format(_ n: Int, _ parsed: Parsed) -> String {
        parsed.usesWords ? NumberWords.word(n, german: parsed.usesGerman) : String(n)
    }
}
