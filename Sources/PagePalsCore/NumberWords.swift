import Foundation

/// Number words 0...20 in English and German, and simple sums such as "three + one =".
public enum NumberWords {
    private static let english = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
                                  "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen",
                                  "eighteen", "nineteen", "twenty"]
    private static let german = ["null", "eins", "zwei", "drei", "vier", "fuenf", "sechs", "sieben", "acht", "neun", "zehn",
                                 "elf", "zwoelf", "dreizehn", "vierzehn", "fuenfzehn", "sechzehn", "siebzehn",
                                 "achtzehn", "neunzehn", "zwanzig"]

    private static func fold(_ s: String) -> String {
        s.lowercased()
            .replacingOccurrences(of: "\u{00FC}", with: "ue")
            .replacingOccurrences(of: "\u{00F6}", with: "oe")
            .replacingOccurrences(of: "\u{00E4}", with: "ae")
            .replacingOccurrences(of: "\u{00DF}", with: "ss")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// "4", "four" or "vier" -> 4. Anything else -> nil.
    public static func value(_ text: String) -> Int? {
        let t = fold(text)
        if let n = Int(t) { return n }
        if let i = english.firstIndex(of: t) { return i }
        if let i = german.firstIndex(of: t) { return i }
        if t == "ein" || t == "eine" { return 1 }
        return nil
    }

    /// The English word for 0...20, otherwise the digits.
    public static func word(_ n: Int) -> String {
        (0..<english.count).contains(n) ? english[n] : String(n)
    }

    /// Solves "three + one =" (also "10 - 4 =", with en dash or minus sign) and gives the answer
    /// in the same style as the question: words for words, digits for digits.
    public static func answer(forSum text: String) -> String? {
        var t = text
        for dash in ["\u{2013}", "\u{2014}", "\u{2212}"] { t = t.replacingOccurrences(of: dash, with: "-") }
        t = t.replacingOccurrences(of: "=", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)

        guard let opIndex = t.firstIndex(where: { $0 == "+" || $0 == "-" }) else { return nil }
        let left = String(t[t.startIndex..<opIndex]).trimmingCharacters(in: .whitespaces)
        let right = String(t[t.index(after: opIndex)...]).trimmingCharacters(in: .whitespaces)
        guard !left.contains(" "), !right.contains(" "),
              let a = value(left), let b = value(right) else { return nil }

        let result = t[opIndex] == "+" ? a + b : a - b
        guard result >= 0 else { return nil }
        let usesDigits = Int(left) != nil && Int(right) != nil
        return usesDigits ? String(result) : word(result)
    }
}
