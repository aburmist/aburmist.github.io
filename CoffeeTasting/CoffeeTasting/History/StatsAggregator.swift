import Foundation

/// The subset of a tasting note the stats need. `TastingNote` conforms; tests use a plain struct.
protocol TastingRecord {
    var createdAt: Date { get }
    var rating: Int { get }
    var isFavorite: Bool { get }
    var descriptors: [String] { get }
}

struct WeeklyCount: Identifiable, Equatable {
    let weekStart: Date
    let count: Int
    var id: Date { weekStart }
}

struct DescriptorCount: Identifiable, Equatable {
    let descriptor: String
    let count: Int
    var id: String { descriptor }
}

struct TastingStats: Equatable {
    var total: Int = 0
    var thisWeek: Int = 0
    var favorites: Int = 0
    /// Average over rated notes only; nil when nothing is rated.
    var averageRating: Double?
    /// Oldest week first.
    var weekly: [WeeklyCount] = []
    var topDescriptors: [DescriptorCount] = []
}

enum StatsAggregator {
    static func compute<R: TastingRecord>(
        _ records: [R],
        now: Date = .now,
        calendar: Calendar = .current,
        weeks: Int = 8,
        topDescriptorLimit: Int = 10
    ) -> TastingStats {
        var stats = TastingStats()
        stats.total = records.count
        stats.favorites = records.filter(\.isFavorite).count

        let rated = records.map(\.rating).filter { $0 > 0 }
        if !rated.isEmpty {
            stats.averageRating = Double(rated.reduce(0, +)) / Double(rated.count)
        }

        if let currentWeek = calendar.dateInterval(of: .weekOfYear, for: now) {
            stats.thisWeek = records.filter { currentWeek.contains($0.createdAt) }.count

            var weekly: [WeeklyCount] = []
            for offset in stride(from: weeks - 1, through: 0, by: -1) {
                guard let start = calendar.date(byAdding: .weekOfYear, value: -offset, to: currentWeek.start),
                      let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start)
                else { continue }
                let count = records.filter { $0.createdAt >= start && $0.createdAt < end }.count
                weekly.append(WeeklyCount(weekStart: start, count: count))
            }
            stats.weekly = weekly
        }

        var counts: [String: Int] = [:]
        for record in records {
            for descriptor in Set(record.descriptors.map { $0.lowercased() }) {
                counts[descriptor, default: 0] += 1
            }
        }
        stats.topDescriptors = counts
            .map { DescriptorCount(descriptor: $0.key, count: $0.value) }
            .sorted { a, b in
                if a.count != b.count { return a.count > b.count }
                return a.descriptor < b.descriptor
            }
            .prefix(topDescriptorLimit)
            .map { $0 }

        return stats
    }
}
