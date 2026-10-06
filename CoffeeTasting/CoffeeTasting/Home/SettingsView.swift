import SwiftUI

/// Everything that is not the cup lives behind the small dot in the corner:
/// history, stats, permission status and app info.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    let permissions: AppPermissions

    var body: some View {
        NavigationStack {
            List {
                Section("Your tastings") {
                    NavigationLink {
                        HistoryListView()
                    } label: {
                        Label("History", systemImage: "clock.arrow.circlepath")
                    }
                    NavigationLink {
                        StatsView()
                    } label: {
                        Label("Stats", systemImage: "chart.bar.xaxis")
                    }
                }

                Section {
                    PermissionRow(title: "Camera", systemImage: "camera", granted: permissions.cameraGranted)
                    PermissionRow(title: "Microphone", systemImage: "mic", granted: permissions.microphoneGranted)
                    PermissionRow(title: "Speech recognition", systemImage: "waveform", granted: permissions.speechGranted)
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        Link(destination: url) {
                            Label("Open iOS Settings", systemImage: "gear")
                        }
                    }
                } header: {
                    Text("Permissions")
                } footer: {
                    Text("The camera is the live background. The microphone and speech recognition turn your spoken notes into text. Nothing leaves your phone unless you share a note.")
                }

                Section("About") {
                    LabeledContent("Version", value: Self.versionString)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private static var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

struct PermissionRow: View {
    let title: String
    let systemImage: String
    let granted: Bool?

    var body: some View {
        LabeledContent {
            Text(statusText)
                .foregroundStyle(granted == false ? Color.red : Color.secondary)
        } label: {
            Label(title, systemImage: systemImage)
        }
    }

    private var statusText: String {
        switch granted {
        case .some(true): return "Allowed"
        case .some(false): return "Not allowed"
        case .none: return "Not asked yet"
        }
    }
}

/// The only chrome on the home screen: a small white dot with a comfortable tap target.
struct SettingsDotButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(.white.opacity(0.72))
                .frame(width: 9, height: 9)
                .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Settings")
    }
}

#Preview {
    SettingsView(permissions: AppPermissions())
        .modelContainer(for: TastingNote.self, inMemory: true)
}
