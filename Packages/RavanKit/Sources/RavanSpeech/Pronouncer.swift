import AVFoundation
import Observation
import RavanModel

/// Speaks English with an American or British voice using the on-device synthesizer.
/// Prefers the highest-quality installed voice for each accent (Premium → Enhanced → Default).
@MainActor
@Observable
public final class Pronouncer: NSObject {
    /// The text currently being spoken — lets the UI animate the right speaker button.
    public private(set) var speakingText: String?

    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()
    @ObservationIgnored private var voices: [Accent: AVSpeechSynthesisVoice] = [:]

    override public init() {
        super.init()
        synthesizer.delegate = self
    }

    /// - Parameter rate: 0.5 (slow) … 1.5 (fast); 1 is the natural speaking rate.
    public func speak(_ text: String, accent: Accent, rate: Double = 1) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        configureAudioSession()
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }

        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = voice(for: accent)
        let base = Double(AVSpeechUtteranceDefaultSpeechRate)
        let scaled = base * min(max(rate, 0.5), 1.5)
        utterance.rate = Float(min(max(scaled, Double(AVSpeechUtteranceMinimumSpeechRate)), Double(AVSpeechUtteranceMaximumSpeechRate)))
        utterance.prefersAssistiveTechnologySettings = true
        speakingText = trimmed
        synthesizer.speak(utterance)
    }

    public func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        speakingText = nil
    }

    private func voice(for accent: Accent) -> AVSpeechSynthesisVoice? {
        if let cached = voices[accent] { return cached }
        let candidates = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == accent.voiceLanguage }
        let best = candidates.max { $0.quality.rawValue < $1.quality.rawValue }
            ?? AVSpeechSynthesisVoice(language: accent.voiceLanguage)
        voices[accent] = best
        return best
    }

    /// Plays even when the ring/silent switch is on — expected from a dictionary.
    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)
    }

    fileprivate func finished(_ text: String) {
        if speakingText == text { speakingText = nil }
    }
}

extension Pronouncer: AVSpeechSynthesizerDelegate {
    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let text = utterance.speechString
        Task { @MainActor in self.finished(text) }
    }

    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let text = utterance.speechString
        Task { @MainActor in self.finished(text) }
    }
}
