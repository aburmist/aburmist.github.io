import Charts
import SwiftData
import SwiftUI

/// Simple reporting: headline numbers, tastings per week, and most-used descriptors.
struct StatsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var notes: [TastingNote]

    private var stats: TastingStats {
        StatsAggregator.compute(notes)
    }

    var body: some View {
        NavigationStack {
            Group {
                if notes.isEmpty {
                    ContentUnavailableView(
                        "Nothing to report yet",
                        systemImage: "chart.bar",
                        description: Text("Save a few tastings and your palate trends will show up here.")
                    )
                } else {
                    content
                }
            }
            .navigationTitle("Stats")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var content: some View {
        let stats = self.stats
        return List {
            Section {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatTile(title: "Tastings", value: "\(stats.total)")
                    StatTile(title: "This week", value: "\(stats.thisWeek)")
                    StatTile(title: "Great coffees", value: "\(stats.favorites)")
                    StatTile(
                        title: "Average rating",
                        value: stats.averageRating.map { String(format: "%.1f", $0) } ?? "–"
                    )
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section("Tastings per week") {
                Chart(stats.weekly) { week in
                    BarMark(
                        x: .value("Week", week.weekStart, unit: .weekOfYear),
                        y: .value("Tastings", week.count)
                    )
                    .foregroundStyle(Color.accentColor)
                    .cornerRadius(4)
                    .annotation(position: .top, spacing: 3) {
                        if week.count > 0 {
                            Text("\(week.count)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .weekOfYear)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day(), centered: true)
                            .font(.caption2)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                        AxisGridLine()
                            .foregroundStyle(.quaternary)
                        AxisValueLabel()
                            .font(.caption2)
                    }
                }
                .frame(height: 180)
                .padding(.vertical, 6)
                .accessibilityLabel("Tastings per week for the last \(stats.weekly.count) weeks")
            }

            Section("Most used descriptors") {
                if stats.topDescriptors.isEmpty {
                    Text("No flavor words detected yet. Try describing fruit, chocolate, acidity or body.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    let maxCount = stats.topDescriptors.map(\.count).max() ?? 1
                    ForEach(stats.topDescriptors) { item in
                        DescriptorBarRow(item: item, maxCount: maxCount)
                    }
                }
            }
        }
    }
}

struct StatTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title.weight(.semibold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct DescriptorBarRow: View {
    let item: DescriptorCount
    let maxCount: Int

    var body: some View {
        HStack(spacing: 12) {
            Text(item.descriptor)
                .frame(width: 120, alignment: .leading)
                .lineLimit(1)
            ProgressView(value: Double(item.count), total: Double(max(maxCount, 1)))
                .tint(Color.accentColor)
            Text("\(item.count)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.descriptor), \(item.count) tastings")
    }
}

#Preview {
    StatsView()
        .modelContainer(for: TastingNote.self, inMemory: true)
}
