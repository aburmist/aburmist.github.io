import Foundation

/// Finds flavor-wheel descriptors mentioned in a free-text tasting note.
struct DescriptorExtractor {
    var vocabulary: [String] = FlavorVocabulary.matchOrder

    /// Returns the canonical descriptors found in `text`, ordered by first appearance.
    /// Simple plurals are matched ("berries" → "berry", "nuts" → "nutty" is not attempted).
    func extract(from text: String) -> [String] {
        let lowered = text.lowercased()
        guard !lowered.isEmpty else { return [] }

        var found: [(position: Int, term: String)] = []
        var consumed: [Range<String.Index>] = []

        for term in vocabulary {
            guard let regex = Self.regex(for: term) else { continue }
            let matches = lowered.matches(of: regex)
            for match in matches {
                let range = match.range
                // Skip words already claimed by a longer term (e.g. "chocolate" inside
                // "dark chocolate").
                if consumed.contains(where: { $0.overlaps(range) }) { continue }
                consumed.append(range)
                let position = lowered.distance(from: lowered.startIndex, to: range.lowerBound)
                found.append((position, term))
                break
            }
        }

        var seen = Set<String>()
        return found
            .sorted { $0.position < $1.position }
            .map(\.term)
            .filter { seen.insert($0).inserted }
    }

    private static var cache: [String: Regex<AnyRegexOutput>] = [:]
    private static let cacheLock = NSLock()

    private static func regex(for term: String) -> Regex<AnyRegexOutput>? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if let cached = cache[term] { return cached }

        var pattern = NSRegularExpression.escapedPattern(for: term)
        if term.hasSuffix("y"), !term.hasSuffix("ey") {
            // "berry" → "berries", "nutty" → "nuttiness"
            pattern = String(pattern.dropLast()) + "(?:y|ies|iness)"
        } else {
            // "sweet" → "sweets", "sweetness"; "chocolate" → "chocolatey"
            pattern += "(?:s|es|ness|ish|y)?"
        }
        // Treat hyphens and spaces in terms as interchangeable with whitespace.
        pattern = pattern.replacingOccurrences(of: "\\-", with: "-")
        pattern = pattern.replacingOccurrences(of: "-", with: "[\\s-]")
        pattern = pattern.replacingOccurrences(of: " ", with: "\\s+")
        let full = "\\b" + pattern + "\\b"
        guard let regex = try? Regex(full) else { return nil }
        cache[term] = regex
        return regex
    }
}
