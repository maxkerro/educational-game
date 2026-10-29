import AVFoundation
import PagePalsCore

/// Reads words and sentences aloud with the voices installed on the Mac; works offline (PP-028).
@MainActor
final class Speaker {
    static let shared = Speaker()
    private let synthesizer = AVSpeechSynthesizer()

    /// Returns false, and says nothing, when no voice for the book language is installed on this Mac:
    /// the default voice would read German or Russian text with English sounds.
    @discardableResult
    func say(_ text: String, language: BookLanguage, settings: SpeechSettings = SpeechSettings()) -> Bool {
        guard let voice = AVSpeechSynthesisVoice(language: settings.voiceLanguage(for: language)) else { return false }
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = settings.utteranceRate
        synthesizer.speak(utterance)
        return true
    }
}
