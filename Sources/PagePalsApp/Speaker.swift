import AVFoundation
import PagePalsCore

/// Reads words and sentences aloud with the voices installed on the Mac; works offline (PP-028).
@MainActor
final class Speaker {
    static let shared = Speaker()
    private let synthesizer = AVSpeechSynthesizer()

    func say(_ text: String, language: BookLanguage, settings: SpeechSettings = SpeechSettings()) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: settings.voiceLanguage(for: language))
        utterance.rate = settings.utteranceRate
        synthesizer.speak(utterance)
    }
}
