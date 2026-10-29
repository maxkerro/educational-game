import Foundation

/// Sums and differences with units and money: `3 m + 20 cm =`, `1 h 30 min + 45 min =`,
/// `2,50 € + 1,20 € =`, `1 kg - 250 g =`, and comparing `3 m _ 250 cm`.
///
/// Units (English and German spelling): mm cm dm m km, mg g kg t, ml cl l, s min h, ct cent € euro.
/// The answer is written in the style of the question: the smallest unit used ("320 cm"), or, when a
/// term is written with two units ("1 h 30 min"), with those units ("2 h 15 min"). Money with decimals
/// keeps its separator and its currency sign ("3,70 €"). Anything else, and any negative result, gives nil.
public enum QuantitySolver {
    enum Family { case length, mass, volume, time, money }

    struct UnitInfo {
        let family: Family
        let factor: Int      // size in the smallest unit of its family (mm, mg, ml, s, cent)
    }

    static let units: [String: UnitInfo] = [
        "mm": UnitInfo(family: .length, factor: 1), "cm": UnitInfo(family: .length, factor: 10),
        "dm": UnitInfo(family: .length, factor: 100), "m": UnitInfo(family: .length, factor: 1000),
        "km": UnitInfo(family: .length, factor: 1_000_000),
        "mg": UnitInfo(family: .mass, factor: 1), "g": UnitInfo(family: .mass, factor: 1000),
        "kg": UnitInfo(family: .mass, factor: 1_000_000), "t": UnitInfo(family: .mass, factor: 1_000_000_000),
        "ml": UnitInfo(family: .volume, factor: 1), "cl": UnitInfo(family: .volume, factor: 10),
        "l": UnitInfo(family: .volume, factor: 1000),
        "s": UnitInfo(family: .time, factor: 1), "sec": UnitInfo(family: .time, factor: 1),
        "min": UnitInfo(family: .time, factor: 60), "h": UnitInfo(family: .time, factor: 3600),
        "std": UnitInfo(family: .time, factor: 3600),
        "ct": UnitInfo(family: .money, factor: 1), "cent": UnitInfo(family: .money, factor: 1),
        "\u{20AC}": UnitInfo(family: .money, factor: 100), "eur": UnitInfo(family: .money, factor: 100),
        "euro": UnitInfo(family: .money, factor: 100)
    ]

    /// One number with its unit as written ("20 cm", "€ 2,50").
    struct Part {
        let unitName: String       // lower case key into `units`
        let printed: String        // the unit as printed
        let info: UnitInfo
        let value: Int             // in the smallest unit of the family
        let decimals: Int          // digits after the separator in the text
        let commaSeparator: Bool
        let prefixUnit: Bool       // "€ 2,50" instead of "2,50 €"
    }

    enum Piece {
        case number(digits: String, decimals: Int, comma: Bool)
        case unit(name: String, printed: String)
        case op(Character)
        case equals
        case blank
    }

    /// `language` decides the decimal separator of an answer when no number in the question shows one
    /// ("2 € + 50 ct" is "2,50 €" in German, "2.50 €" in English).
    public static func solve(_ text: String, language: BookLanguage? = nil) -> String? {
        guard let pieces = scan(text) else { return nil }

        // Split into terms (lists of parts) and the signs between them.
        var terms: [[Part]] = []
        var signs: [Character] = []
        var current: [Part] = []
        var endMark: Piece?          // .equals or .blank that ends the calculation
        var sawEquals = false
        var blanks = 0
        var i = 0
        while i < pieces.count {
            switch pieces[i] {
            case .number(let digits, let decimals, let comma):
                guard i + 1 < pieces.count, case .unit(let name, let printed) = pieces[i + 1],
                      let part = makePart(digits: digits, decimals: decimals, comma: comma, unitName: name, printed: printed, prefix: false)
                else { return nil }
                current.append(part)
                i += 2
            case .unit(let name, let printed):
                guard i + 1 < pieces.count, case .number(let digits, let decimals, let comma) = pieces[i + 1],
                      let part = makePart(digits: digits, decimals: decimals, comma: comma, unitName: name, printed: printed, prefix: true)
                else { return nil }
                current.append(part)
                i += 2
            case .op(let sign):
                guard !current.isEmpty, !sawEquals else { return nil }
                terms.append(current)
                signs.append(sign)
                current = []
                i += 1
            case .equals:
                guard !current.isEmpty, !sawEquals else { return nil }
                terms.append(current)
                current = []
                sawEquals = true
                endMark = .equals
                i += 1
            case .blank:
                blanks += 1
                if !current.isEmpty, !sawEquals {          // "3 m _ 250 cm": the blank sits between two terms
                    terms.append(current)
                    current = []
                    endMark = .blank
                }
                i += 1
            }
        }
        if !current.isEmpty, !sawEquals { terms.append(current) }
        guard !terms.isEmpty else { return nil }

        // Comparing: exactly two terms, no sign, one blank, no equals
        if endMark == nil || isBlank(endMark) {
            guard !sawEquals, signs.isEmpty, blanks == 1, terms.count == 2,
                  let a = total(terms[0]), let b = total(terms[1]), family(terms[0]) == family(terms[1]) else { return nil }
            return a > b ? ">" : (a < b ? "<" : "=")
        }

        // Calculating: terms with signs, then "=" and nothing or one blank
        guard sawEquals, terms.count == signs.count + 1, blanks <= 1, let fam = family(terms[0]) else { return nil }
        var result = 0
        for (index, term) in terms.enumerated() {
            guard family(term) == fam, let value = total(term) else { return nil }
            if index == 0 { result = value } else { result += signs[index - 1] == "+" ? value : -value }
        }
        guard result >= 0 else { return nil }
        return format(result, fam, terms: terms, language: language)
    }

    // MARK: - Reading the text

    private static func isBlank(_ piece: Piece?) -> Bool {
        if case .blank? = piece { return true }
        return false
    }

    private static func scan(_ text: String) -> [Piece]? {
        var pieces: [Piece] = []
        let c = Array(text)
        var i = 0
        while i < c.count {
            let ch = c[i]
            if ch.isWhitespace {
                i += 1
            } else if ch.isASCII && ch.isNumber {
                var digits = ""
                var j = i
                while j < c.count, c[j].isASCII, c[j].isNumber { digits.append(c[j]); j += 1 }
                var decimals = 0
                var comma = false
                if j + 1 < c.count, c[j] == "," || c[j] == ".", c[j + 1].isASCII, c[j + 1].isNumber {
                    comma = c[j] == ","
                    j += 1
                    while j < c.count, c[j].isASCII, c[j].isNumber { digits.append(c[j]); decimals += 1; j += 1 }
                }
                guard digits.count <= 9, decimals <= 3 else { return nil }
                // "1.000 m" / "1,000 m" is one thousand in one language and one in the other: do not guess
                if decimals == 3 { return nil }
                pieces.append(.number(digits: digits, decimals: decimals, comma: comma))
                i = j
            } else if ch.isLetter || ch == "\u{20AC}" {
                var j = i + 1
                if ch.isLetter { while j < c.count, c[j].isLetter { j += 1 } }
                let printed = String(c[i..<j])
                if j < c.count, c[j] == ".", ch.isLetter { j += 1 }      // "min." / "Std."
                guard units[printed.lowercased()] != nil else { return nil }
                pieces.append(.unit(name: printed.lowercased(), printed: printed))
                i = j
            } else {
                switch ch {
                case "+": pieces.append(.op("+"))
                case "-", "\u{2013}", "\u{2014}", "\u{2212}": pieces.append(.op("-"))
                case "=": pieces.append(.equals)
                case "_", "\u{25A1}", "?", "\u{2026}": pieces.append(.blank)
                case ".", ",": break
                default: return nil
                }
                i += 1
            }
        }
        // a run of blank marks is one blank
        var merged: [Piece] = []
        for piece in pieces {
            if case .blank = piece, let last = merged.last, case .blank = last { continue }
            merged.append(piece)
        }
        return merged
    }

    private static func makePart(digits: String, decimals: Int, comma: Bool, unitName: String, printed: String, prefix: Bool) -> Part? {
        guard let info = units[unitName], let number = Int(digits) else { return nil }
        var scale = 1
        for _ in 0..<decimals { scale *= 10 }
        let (product, overflow) = number.multipliedReportingOverflow(by: info.factor)
        guard !overflow, product % scale == 0 else { return nil }
        return Part(unitName: unitName, printed: printed, info: info, value: product / scale,
                    decimals: decimals, commaSeparator: comma, prefixUnit: prefix)
    }

    private static func family(_ term: [Part]) -> Family? {
        guard let first = term.first, term.allSatisfy({ $0.info.family == first.info.family }) else { return nil }
        return first.info.family
    }

    private static func total(_ term: [Part]) -> Int? {
        guard family(term) != nil else { return nil }
        return term.reduce(0) { $0 + $1.value }
    }

    // MARK: - Writing the answer

    private static func format(_ amount: Int, _ fam: Family, terms: [[Part]], language: BookLanguage?) -> String? {
        let all = terms.flatMap { $0 }

        // Money with euros (also mixed with cents): "3,70 €"
        if fam == .money, let sign = all.first(where: { $0.info.factor == 100 }) {
            let anyDecimals = all.contains { $0.decimals > 0 }
            let euros = amount / 100
            let cents = amount % 100
            let separator: String
            if all.contains(where: { $0.commaSeparator }) {
                separator = ","
            } else if all.contains(where: { $0.decimals > 0 }) {
                separator = "."
            } else {
                separator = language == .english ? "." : ","
            }

            if !anyDecimals && cents == 0 { return sign.prefixUnit ? "\(sign.printed) \(euros)" : "\(euros) \(sign.printed)" }
            guard cents >= 0 else { return nil }
            let number = "\(euros)\(separator)" + (cents < 10 ? "0\(cents)" : "\(cents)")
            return sign.prefixUnit ? "\(sign.printed) \(number)" : "\(number) \(sign.printed)"
        }

        // A term written with two or more units gives the answer in those units
        if let compound = terms.first(where: { $0.count >= 2 }) {
            var seen = Set<String>()
            let ordered = compound.filter { seen.insert($0.unitName).inserted }.sorted { $0.info.factor > $1.info.factor }
            var rest = amount
            var written: [String] = []
            for part in ordered {
                let n = rest / part.info.factor
                rest %= part.info.factor
                if n > 0 { written.append("\(n) \(part.printed)") }
            }
            guard rest == 0 else { return nil }
            if written.isEmpty, let last = ordered.last { return "0 \(last.printed)" }
            return written.joined(separator: " ")
        }

        // Otherwise the smallest unit that occurs
        guard let smallest = all.min(by: { $0.info.factor < $1.info.factor }) else { return nil }
        guard amount % smallest.info.factor == 0 else { return nil }
        return "\(amount / smallest.info.factor) \(smallest.printed)"
    }
}
