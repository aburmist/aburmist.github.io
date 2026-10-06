import Foundation
import Observation

/// Reveals a target string one character per tick so live dictation reads like a typewriter.
///
/// Speech recognition revises earlier words as it refines a sentence, so the target can change
/// underneath the displayed text. When that happens the displayed text is trimmed back to the
/// longest common prefix and typing resumes from there, which reads as a quick, natural correction.
@Observable
final class TypewriterModel {
    private(set) var displayed: String = ""
    private(set) var target: String = ""
    /// Characters revealed per tick.
    var charactersPerTick: Int = 1

    var isCaughtUp: Bool { displayed == target }

    func setTarget(_ text: String) {
        target = text
    }

    /// Advances the reveal. Returns `true` when `displayed` changed.
    @discardableResult
    func tick() -> Bool {
        if displayed == target { return false }

        if !target.hasPrefix(displayed) {
            // Recognition rewrote something we already showed: back up to the common prefix.
            let common = displayed.commonPrefix(with: target)
            displayed = common
            return true
        }

        let revealed = displayed.count
        let next = min(target.count, revealed + max(1, charactersPerTick))
        displayed = String(target.prefix(next))
        return true
    }

    /// Shows the full target immediately.
    func flush() {
        displayed = target
    }

    func reset() {
        displayed = ""
        target = ""
    }
}
