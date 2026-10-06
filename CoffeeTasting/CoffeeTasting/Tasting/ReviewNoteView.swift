import SwiftUI

/// Sheet for reviewing, editing and saving a tasting. Also used to edit saved notes.
struct ReviewNoteView: View {
    @State private var draft: TastingDraft
    @State private var confirmDiscard = false
    @FocusState private var transcriptFocused: Bool

    let title: String
    /// When true the cancel button is labelled "Discard" and asks for confirmation.
    let confirmsDiscard: Bool
    let onSave: (TastingDraft) -> Void
    let onDiscard: () -> Void

    init(
        draft: TastingDraft,
        title: String,
        confirmsDiscard: Bool = true,
        onSave: @escaping (TastingDraft) -> Void,
        onDiscard: @escaping () -> Void
    ) {
        _draft = State(initialValue: draft)
        self.title = title
        self.confirmsDiscard = confirmsDiscard
        self.onSave = onSave
        self.onDiscard = onDiscard
    }

    private var descriptors: [String] {
        DescriptorExtractor().extract(from: draft.transcript)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $draft.transcript)
                        .frame(minHeight: 160)
                        .focused($transcriptFocused)
                } header: {
                    Text("Tasting notes")
                } footer: {
                    if draft.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Nothing was transcribed. Type your notes or discard this tasting.")
                    }
                }

                Section("Coffee") {
                    TextField("Coffee name", text: $draft.coffeeName)
                        .textInputAutocapitalization(.words)
                    TextField("Roaster", text: $draft.roaster)
                        .textInputAutocapitalization(.words)
                }

                Section("Rating") {
                    StarRatingView(rating: $draft.rating)
                    Toggle(isOn: $draft.isFavorite) {
                        Label("Great coffee", systemImage: "star")
                    }
                }

                if !descriptors.isEmpty {
                    Section("Descriptors found") {
                        DescriptorChips(descriptors: descriptors)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(confirmsDiscard ? "Discard" : "Cancel", role: confirmsDiscard ? .destructive : .cancel) {
                        if confirmsDiscard {
                            confirmDiscard = true
                        } else {
                            onDiscard()
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(draft) }
                        .fontWeight(.semibold)
                        .disabled(!draft.canSave)
                }
            }
            .confirmationDialog("Discard this tasting?", isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button("Discard", role: .destructive) { onDiscard() }
                Button("Keep editing", role: .cancel) {}
            }
        }
    }
}

struct StarRatingView: View {
    @Binding var rating: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...5, id: \.self) { star in
                Button {
                    rating = (rating == star) ? 0 : star
                } label: {
                    Image(systemName: star <= rating ? "star.fill" : "star")
                        .font(.title2)
                        .foregroundStyle(star <= rating ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(star) star\(star == 1 ? "" : "s")")
            }
            Spacer()
            Text(rating == 0 ? "Unrated" : "\(rating)/5")
                .foregroundStyle(.secondary)
                .font(.subheadline)
        }
        .accessibilityElement(children: .contain)
    }
}

struct DescriptorChips: View {
    let descriptors: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(descriptors, id: \.self) { descriptor in
                    Text(descriptor)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.accentColor.opacity(0.15), in: Capsule())
                }
            }
            .padding(.vertical, 2)
        }
    }
}

#Preview {
    ReviewNoteView(
        draft: TastingDraft(transcript: "Juicy, bright citrus with a brown sugar sweetness and a long finish."),
        title: "Review tasting",
        onSave: { _ in },
        onDiscard: {}
    )
}
