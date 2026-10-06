import AVFoundation
import Foundation
import Observation

/// Runs the back camera for the live background. Has no audio input so it never fights the
/// microphone session used for dictation.
@Observable
final class CameraController {
    enum State: Equatable {
        case idle
        case running
        case denied
        case unavailable
    }

    private(set) var state: State = .idle

    @ObservationIgnored let session = AVCaptureSession()
    @ObservationIgnored private let queue = DispatchQueue(label: "com.aburmist.CoffeeTasting.camera")
    @ObservationIgnored private var configurationResult: Bool?

    func start() {
        #if targetEnvironment(simulator)
        state = .unavailable
        #else
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            state = .idle
            return
        default:
            state = .denied
            return
        }
        queue.async { [self] in
            if configurationResult == nil {
                configurationResult = configure()
            }
            guard configurationResult == true else {
                DispatchQueue.main.async { self.state = .unavailable }
                return
            }
            if !session.isRunning {
                session.startRunning()
            }
            let running = session.isRunning
            DispatchQueue.main.async { self.state = running ? .running : .unavailable }
        }
        #endif
    }

    func stop() {
        queue.async { [self] in
            if session.isRunning { session.stopRunning() }
            DispatchQueue.main.async { self.state = .idle }
        }
    }

    private func configure() -> Bool {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .high
        session.automaticallyConfiguresApplicationAudioSession = false

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input)
        else {
            return false
        }
        session.addInput(input)
        return true
    }
}
