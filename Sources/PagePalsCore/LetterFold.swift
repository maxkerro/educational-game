import Foundation

/// Splits a word into upper-case letters, one string per letter. The German sharp s stays a single
/// letter (plain `uppercased()` would turn it into "SS" and change the length of the word).
enum LetterFold {
    static func letters(_ text: String) -> [String] {
        text.filter { $0.isLetter }.map { ch in ch == "\u{00DF}" ? "\u{00DF}" : String(ch).uppercased() }
    }
}
