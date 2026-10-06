import Foundation
import Observation
import SwiftData

/// State machine for one tasting: prompt → record → review → save/discard.
@Observable
final class TastingSession {
    enum Phase: Equatable {
        case idle
        case prompting
        case recording
        case finishing
        case reviewing
    }

    private(set) var phase: Phase = .idle
    var draft = TastingDraft()
    var errorMessage: String?

    let speech = SpeechRecognizer()
    let typewriter = TypewriterModel()

    @ObservationIgnored private var ticker: Timer?

    var isRecording: Bool { phase == .recording }

    // MARK: Prompt

    func promptIfIdle() {
        guard phase == .idle else { return }
        phase = .prompting
    }

    func cancelPrompt() {
        if phase == .prompting { phase = .idle }
    }

    // MARK: Record

    @MainActor
    func startRecording(permissions: AppPermissions) async {
        guard phase == .prompting || phase == .idle else { return }
        let granted = await permissions.ensureSpeechPermissions()
        guard granted else {
            errorMessage = SpeechError.notAuthorized.errorDescription
            phase = .idle
            return
        }
        do {
            typewriter.reset()
            try speech.start()
            phase = .recording
            startTicker()
        } catch {
            errorMessage = error.localizedDescription
            phase = .idle
        }
    }

    func finishRecording() {
        guard phase == .recording else { return }
        speech.stop()
        phase = .finishing
        // Give the recogniser a moment to deliver its final, refined transcript.
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(650))
            guard let self, self.phase == .finishing else { return }
            self.stopTicker()
            self.typewriter.setTarget(self.speech.transcript)
            self.typewriter.flush()
            self.draft = TastingDraft(transcript: self.speech.transcript)
            self.phase = .reviewing
        }
    }

    // MARK: Review

    func discard() {
        stopTicker()
        typewriter.reset()
        draft = TastingDraft()
        phase = .idle
    }

    /// Persists the draft. Returns the saved note, or nil when the draft is empty.
    @discardableResult
    func save(into context: ModelContext) -> TastingNote? {
        guard draft.canSave else { return nil }
        let note = draft.makeNote()
        context.insert(note)
        try? context.save()
        stopTicker()
        typewriter.reset()
        draft = TastingDraft()
        phase = .idle
        return note
    }

    // MARK: Typewriter ticking

    private func startTicker() {
        stopTicker()
        let timer = Timer(timeInterval: 0.035, repeats: true) { [weak self] _ in
            self?.tickTypewriter()
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func tickTypewriter() {
        typewriter.setTarget(speech.transcript)
        typewriter.tick()
    }
}
