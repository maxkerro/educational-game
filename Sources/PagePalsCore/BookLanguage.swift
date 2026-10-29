import Foundation

/// The language of a book (PP-006). The raw value is what a Lesson Pack stores in `language`.
public enum BookLanguage: String, Codable, CaseIterable, Sendable {
    case english = "en"
    case german = "de"
    case russian = "ru"

    /// Vision language codes for reading this book: its own language first, then the others it may mix in.
    public var recognitionLanguages: [String] {
        switch self {
        case .english: return ["en-US", "de-DE"]
        case .german: return ["de-DE", "en-US"]
        case .russian: return ["ru-RU", "en-US"]
        }
    }

    private static let germanWords: Set<String> = ["der", "die", "das", "und", "ist", "ein", "eine", "nicht", "ich", "wir", "sie", "mit", "auf", "für", "den", "dem", "zu", "von", "im", "wie", "schreibe", "ergänze", "lies"]
    private static let englishWords: Set<String> = ["the", "and", "is", "are", "a", "of", "to", "what", "this", "that", "with", "write", "read", "how", "many", "you", "it", "draw"]

    /// Guesses the language from text read off a few pages. Cyrillic letters mean Russian; otherwise the more frequent
    /// common words (and umlauts / ß) decide, and English wins a tie.
    public static func detect(from lines: [String]) -> BookLanguage {
        var letters = 0, cyrillic = 0, german = 0, english = 0
        for line in lines {
            for scalar in line.unicodeScalars where CharacterSet.letters.contains(scalar) {
                letters += 1
                if (0x0400...0x04FF).contains(scalar.value) { cyrillic += 1 }
                if "äöüßÄÖÜẞ".unicodeScalars.contains(scalar) { german += 1 }
            }
            for word in line.lowercased().split(whereSeparator: { !$0.isLetter }) {
                let w = String(word)
                if germanWords.contains(w) { german += 1 }
                if englishWords.contains(w) { english += 1 }
            }
        }
        if letters > 0 && Double(cyrillic) / Double(letters) > 0.3 { return .russian }
        return german > english ? .german : .english
    }
}
