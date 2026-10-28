import Foundation

/// Number words 0...100 in English and German ("seven", "siebenundzwanzig"); sums are in `MathSolver`.
public enum NumberWords {
    /// English words for 0...100 (index = number).
    private static let english: [String] = {
        let base = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
                    "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen",
                    "eighteen", "nineteen"]
        let tens = ["", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety"]
        var all = base
        for n in 20...99 {
            let unit = n % 10
            all.append(unit == 0 ? tens[n / 10] : tens[n / 10] + "-" + base[unit])
        }
        all.append("hundred")
        return all
    }()

    /// German words for 0...100, written with "ue", "oe", "ss" (umlauts are folded before comparing).
    private static let german: [String] = {
        let base = ["null", "eins", "zwei", "drei", "vier", "fuenf", "sechs", "sieben", "acht", "neun", "zehn",
                    "elf", "zwoelf", "dreizehn", "vierzehn", "fuenfzehn", "sechzehn", "siebzehn",
                    "achtzehn", "neunzehn"]
        let units = ["", "ein", "zwei", "drei", "vier", "fuenf", "sechs", "sieben", "acht", "neun"]
        let tens = ["", "", "zwanzig", "dreissig", "vierzig", "fuenfzig", "sechzig", "siebzig", "achtzig", "neunzig"]
        var all = base
        for n in 20...99 {
            let unit = n % 10
            all.append(unit == 0 ? tens[n / 10] : units[unit] + "und" + tens[n / 10])
        }
        all.append("hundert")
        return all
    }()

    private static func fold(_ s: String) -> String {
        s.lowercased()
            .replacingOccurrences(of: "\u{00FC}", with: "ue")
            .replacingOccurrences(of: "\u{00F6}", with: "oe")
            .replacingOccurrences(of: "\u{00E4}", with: "ae")
            .replacingOccurrences(of: "\u{00DF}", with: "ss")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// "4", "four", "vier" or "twenty-one" -> number. Anything else -> nil.
    public static func value(_ text: String) -> Int? {
        let t = fold(text)
        if let n = Int(t) { return n }
        if let i = english.firstIndex(of: t) { return i }
        if let i = german.firstIndex(of: t) { return i }
        if t == "ein" || t == "eine" { return 1 }
        return nil
    }

    /// True for a German number word such as "vier" or "fünfzehn".
    public static func isGerman(_ text: String) -> Bool {
        let t = fold(text)
        return t == "ein" || t == "eine" || (german.contains(t) && !english.contains(t))
    }

    /// The word for 0...100 (English, or German when asked), otherwise the digits.
    public static func word(_ n: Int, german useGerman: Bool = false) -> String {
        let table = useGerman ? german : english
        return (0..<table.count).contains(n) ? table[n] : String(n)
    }

    /// Solves a task line such as "three + one =" (see `MathSolver`) or "3 m + 20 cm =" (see `QuantitySolver`).
    public static func answer(forSum text: String) -> String? {
        MathSolver.solve(text) ?? QuantitySolver.solve(text)
    }
}
