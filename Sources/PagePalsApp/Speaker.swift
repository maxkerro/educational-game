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
        let wanted = settings.voiceLanguage(for: language)
        let prefix = String(wanted.prefix(2))
        // exact locale first ("en-GB"), then any voice of the same language ("en-US")
        guard let voice = AVSpeechSynthesisVoice(language: wanted)
                ?? AVSpeechSynthesisVoice.speechVoices().first(where: { $0.language.hasPrefix(prefix) }) else { return false }
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = settings.utteranceRate
        synthesizer.speak(utterance)
        return true
    }
}
