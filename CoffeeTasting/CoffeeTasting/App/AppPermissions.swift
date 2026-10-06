import AVFoundation
import Foundation
import Observation
import Speech

/// Requests and tracks the three permissions the app needs.
/// Camera is asked for at launch; microphone and speech only when the user first starts talking.
@Observable
final class AppPermissions {
    private(set) var cameraGranted: Bool?
    private(set) var microphoneGranted: Bool?
    private(set) var speechGranted: Bool?

    init() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: cameraGranted = true
        case .denied, .restricted: cameraGranted = false
        default: cameraGranted = nil
        }
        switch AVAudioApplication.shared.recordPermission {
        case .granted: microphoneGranted = true
        case .denied: microphoneGranted = false
        default: microphoneGranted = nil
        }
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: speechGranted = true
        case .denied, .restricted: speechGranted = false
        default: speechGranted = nil
        }
    }

    @MainActor
    @discardableResult
    func requestCamera() async -> Bool {
        if let cameraGranted { return cameraGranted }
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        cameraGranted = granted
        return granted
    }

    /// Microphone + speech recognition. Returns true only when both are granted.
    @MainActor
    func ensureSpeechPermissions() async -> Bool {
        if microphoneGranted == nil {
            microphoneGranted = await AVAudioApplication.requestRecordPermission()
        }
        if speechGranted == nil {
            speechGranted = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status == .authorized)
                }
            }
        }
        return microphoneGranted == true && speechGranted == true
    }

    var cameraDenied: Bool { cameraGranted == false }
    var speechDenied: Bool { microphoneGranted == false || speechGranted == false }
}
