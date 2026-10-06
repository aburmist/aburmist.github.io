import SwiftData
import SwiftUI

/// Chronological, searchable list of saved tastings. Pushed inside the Settings navigation stack.
struct HistoryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TastingNote.createdAt, order: .reverse) private var notes: [TastingNote]
    @State private var searchText = ""
    @State private var favoritesOnly = false

    private var filtered: [TastingNote] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return notes.filter { note in
            if favoritesOnly, !note.isFavorite { return false }
            guard !query.isEmpty else { return true }
            return note.transcript.lowercased().contains(query)
                || note.coffeeName.lowercased().contains(query)
                || note.roaster.lowercased().contains(query)
                || note.descriptors.contains { $0.contains(query) }
        }
    }

    var body: some View {
        Group {
            if notes.isEmpty {
                ContentUnavailableView(
                    "No tastings yet",
                    systemImage: "cup.and.saucer",
                    description: Text("Tap the cup on the home screen and talk about your coffee.")
                )
            } else if filtered.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                List {
                    ForEach(filtered) { note in
                        NavigationLink(value: note) {
                            NoteRow(note: note)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                modelContext.delete(note)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                note.isFavorite.toggle()
                            } label: {
                                Label(note.isFavorite ? "Unmark" : "Great", systemImage: note.isFavorite ? "star.slash" : "star")
                            }
                            .tint(.yellow)
                        }
                        .contextMenu {
                            ShareLink(item: note.shareText) {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationDestination(for: TastingNote.self) { note in
            NoteDetailView(note: note)
        }
        .searchable(text: $searchText, prompt: "Search notes, coffee, roaster")
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    favoritesOnly.toggle()
                } label: {
                    Image(systemName: favoritesOnly ? "star.fill" : "star")
                }
                .accessibilityLabel(favoritesOnly ? "Show all" : "Show great coffees only")
            }
        }
    }
}

struct NoteRow: View {
    let note: TastingNote

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(note.title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                if note.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption)
                }
                if note.rating > 0 {
                    Text(String(repeating: "★", count: note.rating))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text(note.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(note.transcript)
                .font(.subheadline)
                .lineLimit(2)
                .foregroundStyle(.primary.opacity(0.85))
            if !note.descriptors.isEmpty {
                Text(note.descriptors.prefix(4).joined(separator: " · "))
                    .font(.caption2)
                    .foregroundStyle(Color.accentColor)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        HistoryListView()
    }
    .modelContainer(for: TastingNote.self, inMemory: true)
}
