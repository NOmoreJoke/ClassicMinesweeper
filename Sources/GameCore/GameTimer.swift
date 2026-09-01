import Darwin

public struct GameTimer: Equatable, Sendable {
    public private(set) var startedAtNanoseconds: UInt64?
    public private(set) var stoppedAtNanoseconds: UInt64?

    public init() {}

    public var isRunning: Bool {
        startedAtNanoseconds != nil && stoppedAtNanoseconds == nil
    }

    public mutating func start(atNanoseconds now: UInt64) {
        guard startedAtNanoseconds == nil else { return }
        startedAtNanoseconds = now
    }

    public mutating func stop(atNanoseconds now: UInt64) {
        guard isRunning else { return }
        stoppedAtNanoseconds = now
    }

    public func elapsedSeconds(atNanoseconds now: UInt64) -> Int {
        guard let start = startedAtNanoseconds else { return 0 }
        let end = stoppedAtNanoseconds ?? now
        guard end >= start else { return 0 }
        return min(999, Int((end - start) / 1_000_000_000))
    }
}

public enum ContinuousTime {
    public static func nowNanoseconds() -> UInt64 {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        let ticks = mach_continuous_time()
        let product = ticks.multipliedFullWidth(by: UInt64(info.numer))
        return UInt64(info.denom).dividingFullWidth(product).quotient
    }
}
