import Foundation

/// How much coffee is in the cup, how hot it still is, and when it gets refilled.
///
/// Sipping (holding the drinking gesture past `sipThreshold`) lowers the level. An empty cup
/// refills on its own after a short idle period, a partially drunk one after a longer wait, and
/// saving a tasting note always pours a fresh cup.
struct CupFillModel: Equatable {
    enum Event: Equatable {
        case none
        case sipStarted
        case becameEmpty
        case refillStarted
        case refillFinished
    }

    var sipThreshold: Double = 0.7
    /// Fraction of the cup drunk per second at full drink factor.
    var sipRate: Double = 0.06
    /// Below this level the cup counts as empty.
    var emptyLevel: Double = 0.08
    /// Idle time before an empty cup refills.
    var emptyRefillDelay: TimeInterval = 6
    /// Idle time before a partially drunk cup refills.
    var partialRefillDelay: TimeInterval = 45
    var refillDuration: TimeInterval = 2
    /// Seconds for the coffee to go from piping hot to no steam.
    var coolingTime: TimeInterval = 600

    private(set) var fillLevel: Double = 1
    private(set) var heat: Double = 1
    private(set) var isSipping = false
    private(set) var isRefilling = false
    private(set) var idleTime: TimeInterval = 0
    private var refillProgress: Double = 0
    private var refillFrom: Double = 0

    var isEmpty: Bool { fillLevel <= emptyLevel + 1e-9 }

    /// Steam intensity in 0...1 derived from fill and heat.
    var steamIntensity: Double {
        guard !isEmpty else { return 0 }
        return clamp(heat, 0, 1) * clamp(fillLevel, 0, 1)
    }

    mutating func update(drinkFactor: Double, dt: TimeInterval) -> Event {
        guard dt > 0, dt.isFinite else { return .none }
        heat = max(0, heat - dt / coolingTime)

        if isRefilling {
            refillProgress = min(1, refillProgress + dt / refillDuration)
            let eased = 1 - pow(1 - refillProgress, 3)
            fillLevel = refillFrom + (1 - refillFrom) * eased
            if refillProgress >= 1 {
                isRefilling = false
                fillLevel = 1
                return .refillFinished
            }
            return .none
        }

        if drinkFactor > sipThreshold, !isEmpty {
            let wasSipping = isSipping
            isSipping = true
            idleTime = 0
            fillLevel = max(emptyLevel, fillLevel - sipRate * drinkFactor * dt)
            if !wasSipping { return .sipStarted }
            if isEmpty { return .becameEmpty }
            return .none
        }

        isSipping = false
        guard fillLevel < 1, drinkFactor < 0.1 else {
            idleTime = 0
            return .none
        }
        idleTime += dt
        let delay = isEmpty ? emptyRefillDelay : partialRefillDelay
        if idleTime >= delay {
            return beginRefill()
        }
        return .none
    }

    /// Pours a fresh cup immediately (e.g. after a tasting note is saved).
    @discardableResult
    mutating func refill() -> Event {
        guard !isRefilling, fillLevel < 1 else {
            heat = 1
            return .none
        }
        return beginRefill()
    }

    private mutating func beginRefill() -> Event {
        isRefilling = true
        isSipping = false
        idleTime = 0
        refillProgress = 0
        refillFrom = fillLevel
        heat = 1
        return .refillStarted
    }
}
