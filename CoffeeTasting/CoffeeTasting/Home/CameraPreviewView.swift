import AVFoundation
import SwiftUI
import UIKit

/// Full-bleed camera preview backed by `AVCaptureVideoPreviewLayer`.
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        if uiView.previewLayer.session !== session {
            uiView.previewLayer.session = session
        }
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            // The app is portrait-only; keep the feed upright.
            if let connection = previewLayer.connection, connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
        }
    }
}

/// Camera feed when available, otherwise a warm dark gradient (Simulator, denied permission).
struct CameraBackground: View {
    let controller: CameraController

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.16, green: 0.12, blue: 0.10),
                    Color(red: 0.07, green: 0.05, blue: 0.045),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            if controller.state == .running {
                CameraPreviewView(session: controller.session)
            }
        }
        .ignoresSafeArea()
    }
}
