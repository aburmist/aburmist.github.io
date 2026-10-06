import Foundation
import SwiftData

@Model
final class TastingNote {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var transcript: String
    var coffeeName: String
    var roaster: String
    /// 0 = unrated, otherwise 1...5.
    var rating: Int
    var isFavorite: Bool
    var descriptors: [String]

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        transcript: String,
        coffeeName: String = "",
        roaster: String = "",
        rating: Int = 0,
        isFavorite: Bool = false,
        descriptors: [String] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.transcript = transcript
        self.coffeeName = coffeeName
        self.roaster = roaster
        self.rating = rating
        self.isFavorite = isFavorite
        self.descriptors = descriptors
    }

    var title: String {
        let name = coffeeName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Untitled tasting" : name
    }

    var subtitle: String {
        let roasterName = roaster.trimmingCharacters(in: .whitespacesAndNewlines)
        let date = createdAt.formatted(date: .abbreviated, time: .shortened)
        return roasterName.isEmpty ? date : "\(roasterName) · \(date)"
    }

    /// Plain-text summary used by the share sheet.
    var shareText: String {
        var lines: [String] = []
        lines.append("☕️ \(title)")
        if !roaster.isEmpty { lines.append("Roaster: \(roaster)") }
        if rating > 0 { lines.append(String(repeating: "★", count: rating) + String(repeating: "☆", count: 5 - rating)) }
        lines.append(createdAt.formatted(date: .long, time: .shortened))
        lines.append("")
        lines.append(transcript)
        if !descriptors.isEmpty {
            lines.append("")
            lines.append("Notes: " + descriptors.joined(separator: ", "))
        }
        return lines.joined(separator: "\n")
    }
}

extension TastingNote: TastingRecord {}

/// Editable copy of a note used by the review sheet.
struct TastingDraft: Equatable {
    var transcript: String = ""
    var coffeeName: String = ""
    var roaster: String = ""
    var rating: Int = 0
    var isFavorite: Bool = false

    init(transcript: String = "") {
        self.transcript = transcript
    }

    init(note: TastingNote) {
        transcript = note.transcript
        coffeeName = note.coffeeName
        roaster = note.roaster
        rating = note.rating
        isFavorite = note.isFavorite
    }

    var trimmedTranscript: String {
        transcript.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canSave: Bool { !trimmedTranscript.isEmpty }

    func apply(to note: TastingNote) {
        note.transcript = trimmedTranscript
        note.coffeeName = coffeeName.trimmingCharacters(in: .whitespacesAndNewlines)
        note.roaster = roaster.trimmingCharacters(in: .whitespacesAndNewlines)
        note.rating = rating
        note.isFavorite = isFavorite
        note.descriptors = DescriptorExtractor().extract(from: note.transcript)
    }

    func makeNote() -> TastingNote {
        let note = TastingNote(transcript: trimmedTranscript)
        apply(to: note)
        return note
    }
}
