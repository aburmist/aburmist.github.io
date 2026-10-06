import SwiftData
import SwiftUI

/// Camera feed, 3D cup, live transcript and the controls around them.
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @State private var camera = CameraController()
    @State private var permissions = AppPermissions()
    @State private var session = TastingSession()

    @State private var showSettings = false
    @State private var refillTrigger = 0
    @State private var savedToastVisible = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                CameraBackground(controller: camera)

                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    FoggyTranscriptView(text: session.typewriter.displayed)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 8)
                    CupSceneView(refillTrigger: refillTrigger) {
                        session.promptIfIdle()
                    }
                    .frame(height: proxy.size.height * 0.46)
                }
                .ignoresSafeArea(edges: .bottom)

                controls(height: proxy.size.height)
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .confirmationDialog("Talk about this coffee?", isPresented: promptBinding, titleVisibility: .visible) {
            Button("Start talking") {
                Task { await session.startRecording(permissions: permissions) }
            }
            Button("Cancel", role: .cancel) { session.cancelPrompt() }
        } message: {
            Text("Describe the aroma, flavor, body and finish. Your words will appear above the cup.")
        }
        .sheet(isPresented: reviewBinding) {
            ReviewNoteView(draft: session.draft, title: "Review tasting") { draft in
                session.draft = draft
                if session.save(into: modelContext) != nil {
                    refillTrigger += 1
                    showSavedToast()
                }
            } onDiscard: {
                session.discard()
            }
            .interactiveDismissDisabled()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(permissions: permissions)
        }
        .alert("Couldn't record", isPresented: errorBinding) {
            Button("OK") { session.errorMessage = nil }
        } message: {
            Text(session.errorMessage ?? "")
        }
        .task {
            await permissions.requestCamera()
            camera.start()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: camera.start()
            case .background: camera.stop()
            default: break
            }
        }
    }

    // MARK: Overlay controls

    @ViewBuilder
    private func controls(height: CGFloat) -> some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                SettingsDotButton { showSettings = true }
            }
            .padding(.trailing, 6)
            .padding(.top, 2)

            Spacer()

            bottomControl
                .padding(.bottom, height * 0.44)

            if savedToastVisible {
                Text("Saved. Fresh cup poured ☕️")
                    .font(.footnote.weight(.medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 24)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: savedToastVisible)
    }

    @ViewBuilder
    private var bottomControl: some View {
        switch session.phase {
        case .recording:
            RecordingBar { session.finishRecording() }
        case .finishing:
            ProgressView("Finishing…")
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
        case .idle where session.typewriter.displayed.isEmpty:
            Text("Tap the cup to talk about your coffee")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.55))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(.black.opacity(0.18), in: Capsule())
        default:
            EmptyView()
        }
    }

    // MARK: Bindings

    private var promptBinding: Binding<Bool> {
        Binding(
            get: { session.phase == .prompting },
            set: { if !$0 { session.cancelPrompt() } }
        )
    }

    private var reviewBinding: Binding<Bool> {
        Binding(
            get: { session.phase == .reviewing },
            set: { _ in }
        )
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { session.errorMessage != nil },
            set: { if !$0 { session.errorMessage = nil } }
        )
    }

    private func showSavedToast() {
        savedToastVisible = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.2))
            savedToastVisible = false
        }
    }
}

// MARK: - Pieces

struct RecordingBar: View {
    let onDone: () -> Void
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.35))
                    .frame(width: 26, height: 26)
                    .scaleEffect(pulse ? 1.5 : 1)
                    .opacity(pulse ? 0 : 1)
                Image(systemName: "mic.fill")
                    .foregroundStyle(.red)
            }
            .onAppear {
                withAnimation(.easeOut(duration: 1.1).repeatForever(autoreverses: false)) {
                    pulse = true
                }
            }
            Text("Listening…")
                .font(.subheadline)
            Button("Done", action: onDone)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

#Preview {
    HomeView()
        .modelContainer(for: TastingNote.self, inMemory: true)
}
