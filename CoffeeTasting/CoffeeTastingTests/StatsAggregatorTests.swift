import XCTest
@testable import CoffeeTasting

final class StatsAggregatorTests: XCTestCase {
    private struct Record: TastingRecord {
        var createdAt: Date
        var rating: Int = 0
        var isFavorite: Bool = false
        var descriptors: [String] = []
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = 2 // Monday
        return calendar
    }

    /// Wednesday 2026-10-07 12:00 UTC.
    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 7, hour: 12))!
    }

    private func daysAgo(_ days: Int) -> Date {
        calendar.date(byAdding: .day, value: -days, to: now)!
    }

    func testEmptyInput() {
        let stats = StatsAggregator.compute([Record](), now: now, calendar: calendar)
        XCTAssertEqual(stats.total, 0)
        XCTAssertEqual(stats.thisWeek, 0)
        XCTAssertNil(stats.averageRating)
        XCTAssertEqual(stats.weekly.count, 8)
        XCTAssertTrue(stats.weekly.allSatisfy { $0.count == 0 })
        XCTAssertTrue(stats.topDescriptors.isEmpty)
    }

    func testTotalsFavoritesAndAverageOverRatedOnly() {
        let records = [
            Record(createdAt: daysAgo(0), rating: 5, isFavorite: true),
            Record(createdAt: daysAgo(1), rating: 3),
            Record(createdAt: daysAgo(2), rating: 0),
        ]
        let stats = StatsAggregator.compute(records, now: now, calendar: calendar)
        XCTAssertEqual(stats.total, 3)
        XCTAssertEqual(stats.favorites, 1)
        XCTAssertEqual(stats.averageRating!, 4, accuracy: 1e-9)
    }

    func testThisWeekAndWeeklyBuckets() {
        let records = [
            Record(createdAt: daysAgo(0)),   // Wed, this week
            Record(createdAt: daysAgo(2)),   // Mon, this week
            Record(createdAt: daysAgo(3)),   // Sun, last week
            Record(createdAt: daysAgo(9)),   // last week
            Record(createdAt: daysAgo(30)),  // ~4 weeks ago
            Record(createdAt: daysAgo(90)),  // outside the 8-week window
        ]
        let stats = StatsAggregator.compute(records, now: now, calendar: calendar, weeks: 8)
        XCTAssertEqual(stats.thisWeek, 2)
        XCTAssertEqual(stats.weekly.count, 8)
        XCTAssertEqual(stats.weekly.last?.count, 2, "newest week is last")
        XCTAssertEqual(stats.weekly[6].count, 2, "previous week")
        XCTAssertEqual(stats.weekly.map(\.count).reduce(0, +), 5, "the 90-day-old record falls outside the window")
        for pair in zip(stats.weekly, stats.weekly.dropFirst()) {
            XCTAssertLessThan(pair.0.weekStart, pair.1.weekStart)
        }
    }

    func testTopDescriptorsSortedByCountThenName() {
        let records = [
            Record(createdAt: now, descriptors: ["citrus", "chocolate"]),
            Record(createdAt: now, descriptors: ["Citrus", "citrus", "floral"]),
            Record(createdAt: now, descriptors: ["chocolate"]),
        ]
        let stats = StatsAggregator.compute(records, now: now, calendar: calendar, topDescriptorLimit: 2)
        XCTAssertEqual(stats.topDescriptors, [
            DescriptorCount(descriptor: "chocolate", count: 2),
            DescriptorCount(descriptor: "citrus", count: 2),
        ])
    }
}
