import SwiftData
import SwiftUI

struct NoteDetailView: View {
    @Bindable var note: TastingNote
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var isEditing = false
    @State private var confirmDelete = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(note.title)
                        .font(.title2.weight(.semibold))
                    Text(note.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        if note.rating > 0 {
                            Text(String(repeating: "★", count: note.rating) + String(repeating: "☆", count: 5 - note.rating))
                                .foregroundStyle(Color.accentColor)
                        }
                        if note.isFavorite {
                            Label("Great coffee", systemImage: "star.fill")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.yellow)
                        }
                    }
                }

                Text(note.transcript)
                    .font(.body)
                    .textSelection(.enabled)

                if !note.descriptors.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Descriptors")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        DescriptorChips(descriptors: note.descriptors)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle("Tasting")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    note.isFavorite.toggle()
                } label: {
                    Image(systemName: note.isFavorite ? "star.fill" : "star")
                }
                .accessibilityLabel(note.isFavorite ? "Unmark great coffee" : "Mark as great coffee")
                ShareLink(item: note.shareText)
                Menu {
                    Button("Edit", systemImage: "pencil") { isEditing = true }
                    Button("Delete", systemImage: "trash", role: .destructive) { confirmDelete = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            ReviewNoteView(draft: TastingDraft(note: note), title: "Edit tasting", confirmsDiscard: false) { draft in
                draft.apply(to: note)
                try? modelContext.save()
                isEditing = false
            } onDiscard: {
                isEditing = false
            }
        }
        .confirmationDialog("Delete this tasting?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                modelContext.delete(note)
                dismiss()
            }
        }
    }
}
