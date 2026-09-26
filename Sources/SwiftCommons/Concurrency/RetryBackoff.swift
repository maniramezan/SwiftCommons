import Foundation

/// How long ``withRetry(attempts:backoff:clock:shouldRetry:operation:)`` waits before each retry.
///
///     // 0.5s, 1s, 2s, 4s, ... capped at 30s, each scaled by a random factor in 0.5...1.5
///     let backoff = RetryBackoff.exponential(
///         baseDelay: .milliseconds(500), maxDelay: .seconds(30), jitter: 0.5...1.5)
///
/// Jitter spreads retries from many clients apart so they don't hit a recovering server in
/// lockstep. Inject `jitterSource` to make the sampled delays deterministic in tests.
public struct RetryBackoff: Sendable {
    private enum Strategy: Sendable {
        case constant(Duration)
        case exponential(
            baseDelay: Duration,
            multiplier: Double,
            maxDelay: Duration?,
            jitter: ClosedRange<Double>,
            jitterSource: @Sendable () -> Double
        )
    }

    /// The longest delay a backoff ever returns, so extreme inputs can't overflow `Duration`.
    private static let longestDelay = Duration.seconds(Int64.max)

    private let strategy: Strategy

    private init(_ strategy: Strategy) {
        self.strategy = strategy
    }

    /// Waits the same `delay` before every retry.
    ///
    /// - Parameter delay: The delay before each retry. Must be at least `.zero`.
    /// - Returns: A constant backoff.
    public static func constant(_ delay: Duration) -> RetryBackoff {
        precondition(delay >= .zero, "delay must be at least .zero")
        return RetryBackoff(.constant(delay))
    }

    /// Multiplies the delay by `multiplier` after every retry, up to an optional cap, then scales
    /// it by a random factor from `jitter`.
    ///
    /// The delay before retry `n` (1-based) is `baseDelay * multiplier^(n - 1)`, capped at
    /// `maxDelay`, then multiplied by a factor sampled from `jitter`. The cap applies before
    /// jitter, so with a jitter range above `1` a capped delay can exceed `maxDelay` by up to
    /// `jitter.upperBound` times. That keeps capped retries spread out instead of all landing on
    /// exactly `maxDelay`.
    ///
    /// - Parameters:
    ///   - baseDelay: The delay before the first retry. Must be at least `.zero`.
    ///   - multiplier: The growth factor between consecutive retries. Must be at least `1`.
    ///     Defaults to `2`.
    ///   - maxDelay: The cap on the delay before jitter is applied. `nil` (the default) means
    ///     no cap.
    ///   - jitter: The range the multiplicative jitter factor is sampled from. The lower bound
    ///     must be at least `0`. Defaults to `1...1` (no jitter); `0.5...1.5` is a common choice.
    ///   - jitterSource: Returns a value in `0...1` used to pick the factor within `jitter`;
    ///     values outside that range are clamped. Defaults to `Double.random(in: 0...1)`. Inject
    ///     a fixed value for deterministic tests.
    /// - Returns: An exponential backoff.
    public static func exponential(
        baseDelay: Duration,
        multiplier: Double = 2,
        maxDelay: Duration? = nil,
        jitter: ClosedRange<Double> = 1...1,
        jitterSource: @escaping @Sendable () -> Double = { Double.random(in: 0...1) }
    ) -> RetryBackoff {
        precondition(baseDelay >= .zero, "baseDelay must be at least .zero")
        precondition(multiplier >= 1, "multiplier must be at least 1")
        precondition(maxDelay.map { $0 >= .zero } ?? true, "maxDelay must be at least .zero")
        precondition(jitter.lowerBound >= 0, "jitter must not be negative")
        return RetryBackoff(
            .exponential(
                baseDelay: baseDelay,
                multiplier: multiplier,
                maxDelay: maxDelay,
                jitter: jitter,
                jitterSource: jitterSource
            ))
    }

    /// The delay to wait before a given retry.
    ///
    /// - Parameter retry: The 1-based number of the retry about to run: `1` is the wait after
    ///   the first failed attempt.
    /// - Returns: The delay before that retry.
    public func delay(forRetry retry: Int) -> Duration {
        switch strategy {
        case .constant(let delay):
            return delay
        case .exponential(let baseDelay, let multiplier, let maxDelay, let jitter, let jitterSource):
            let growth = pow(multiplier, Double(max(0, retry - 1)))
            let capped = Self.scale(
                baseDelay, by: growth, notExceeding: maxDelay ?? Self.longestDelay)
            let unit = min(max(jitterSource(), 0), 1)
            let jitterFactor = jitter.lowerBound + unit * (jitter.upperBound - jitter.lowerBound)
            return Self.scale(capped, by: jitterFactor, notExceeding: Self.longestDelay)
        }
    }

    private static func scale(
        _ duration: Duration, by factor: Double, notExceeding limit: Duration
    ) -> Duration {
        guard duration > .zero else { return .zero }
        guard factor.isFinite, duration.timeInterval * factor < limit.timeInterval else {
            return limit
        }
        return duration * factor
    }
}
