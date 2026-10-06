import AVFoundation
import Foundation
import Observation
import Speech

enum SpeechError: LocalizedError {
    case notAuthorized
    case unavailable
    case audioEngine(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Microphone or speech recognition access was not granted. You can enable both in Settings."
        case .unavailable:
            return "Speech recognition isn't available right now. Check your network or on-device dictation settings."
        case .audioEngine(let error):
            return "The microphone couldn't start: \(error.localizedDescription)"
        }
    }
}

/// Live speech-to-text using Apple's Speech framework, on-device when the language supports it.
/// `transcript` updates continuously with partial results while recording.
@Observable
final class SpeechRecognizer {
    private(set) var transcript = ""
    private(set) var isRecording = false
    private(set) var lastError: String?

    @ObservationIgnored private let recognizer: SFSpeechRecognizer?
    @ObservationIgnored private let audioEngine = AVAudioEngine()
    @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var task: SFSpeechRecognitionTask?
    /// Identifies the current recognition task so late callbacks from a cancelled one are ignored.
    @ObservationIgnored private var currentToken = UUID()

    init(locale: Locale = .autoupdatingCurrent) {
        recognizer = SFSpeechRecognizer(locale: locale) ?? SFSpeechRecognizer()
    }

    var isAvailable: Bool { recognizer?.isAvailable ?? false }
    var isOnDevice: Bool { recognizer?.supportsOnDeviceRecognition ?? false }

    /// Starts the microphone and a new recognition task. Call on the main thread.
    func start() throws {
        guard !isRecording else { return }
        guard SFSpeechRecognizer.authorizationStatus() == .authorized,
              AVAudioApplication.shared.recordPermission == .granted
        else { throw SpeechError.notAuthorized }
        guard let recognizer, recognizer.isAvailable else { throw SpeechError.unavailable }

        cancelTask()

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        request.taskHint = .dictation
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        self.request = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            self.request = nil
            throw SpeechError.audioEngine(error)
        }

        transcript = ""
        lastError = nil
        isRecording = true

        let token = UUID()
        currentToken = token
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.handle(result: result, error: error, token: token)
            }
        }
    }

    /// Stops the microphone. The recogniser may still deliver one final, refined transcript
    /// shortly afterwards, so readers should wait briefly before treating `transcript` as final.
    func stop() {
        guard isRecording else { return }
        isRecording = false
        stopAudio()
        request?.endAudio()
    }

    private func handle(result: SFSpeechRecognitionResult?, error: Error?, token: UUID) {
        guard token == currentToken else { return }
        if let result {
            transcript = result.bestTranscription.formattedString
        }
        if let error {
            // Errors after `stop()` (e.g. "no speech detected" on an empty take) are expected.
            if isRecording {
                lastError = error.localizedDescription
                isRecording = false
                stopAudio()
            }
            request = nil
            task = nil
        } else if result?.isFinal == true {
            request = nil
            task = nil
        }
    }

    private func stopAudio() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func cancelTask() {
        task?.cancel()
        task = nil
        request = nil
    }
}
