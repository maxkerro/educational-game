import Foundation

/// Splits a word into upper-case letters, one string per letter. The German sharp s (ß, and the capital ẞ)
/// stays a single letter; plain `uppercased()` would turn it into "SS" and change the length of the word.
enum LetterFold {
    private static let sharpS = "\u{00DF}"

    static func letters(_ text: String) -> [String] {
        text.filter { $0.isLetter }.map { ch in
            (ch == "\u{00DF}" || ch == "\u{1E9E}") ? sharpS : String(ch).uppercased()
        }
    }

    /// The ways a word can be printed in capitals. A word with ß is printed either with the single letter ß
    /// or as "SS" (STRASSE), so both spellings are returned; any other word has one spelling.
    static func spellings(_ text: String) -> [[String]] {
        let single = letters(text)
        guard single.contains(sharpS) else { return [single] }
        return [single, single.flatMap { $0 == sharpS ? ["S", "S"] : [$0] }]
    }
}
