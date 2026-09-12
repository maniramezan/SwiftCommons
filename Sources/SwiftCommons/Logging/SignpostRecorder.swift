import OSLog

/// A thin, reusable wrapper over `OSSignposter` for measuring hot paths with Instruments.
///
/// `Logger` answers *what* happened; a signpost answers *how long it took* and *where it landed on
/// the frame timeline*. Use this for work that runs during scrolling, animation, or any other
/// budgeted frame — a stall shows up as an interval that overruns the frame, which no amount of log
/// messages will reveal.
///
/// ```swift
/// private let signposts = SignpostRecorder(subsystem: "MyApp", category: "Rendering")
///
/// let grid = signposts.measure("resolveGrid") {
///     expensiveGridResolution()
/// }
/// ```
///
/// Recording is free when no tool is attached: every entry point checks ``isEnabled`` (backed by
/// `OSSignposter.isEnabled`) and calls straight through. Attach with Instruments'
/// **os_signpost** instrument, or:
///
/// ```bash
/// xcrun xctrace record --template 'os_signpost' --attach <pid>
/// ```
///
/// Interval names must be string literals (`StaticString`) because the unified logging system
/// records them by pointer rather than copying them.
public struct SignpostRecorder: Sendable {

    /// The underlying signposter. Exposed for call sites that need the full `OSSignposter` surface
    /// (explicit signpost IDs, concurrent overlapping intervals, animation intervals).
    public let signposter: OSSignposter

    /// Whether a profiling tool is currently listening.
    ///
    /// Guard genuinely expensive instrumentation (building a description string, summing counters)
    /// behind this; the `measure` and `event` methods already check it themselves.
    public var isEnabled: Bool { signposter.isEnabled }

    /// Creates a recorder for a subsystem and category.
    ///
    /// Match the subsystem to the one used for the same code's `Logger` so log messages and
    /// signpost intervals line up on the same filter in Instruments.
    ///
    /// - Parameters:
    ///   - subsystem: Reverse-DNS or package identifier, e.g. `"SwiftCommons"`.
    ///   - category: The area being measured, e.g. `"Rendering"`.
    public init(subsystem: String, category: String) {
        self.signposter = OSSignposter(subsystem: subsystem, category: category)
    }

    /// Creates a recorder around an existing signposter.
    public init(signposter: OSSignposter) {
        self.signposter = signposter
    }

    /// Returns a recorder in the SwiftCommons subsystem, mirroring
    /// ``Logger/swiftCommonsLogger(category:)``.
    public static func swiftCommons(category: String) -> SignpostRecorder {
        SignpostRecorder(subsystem: Logger.swiftCommonsSubsystem, category: category)
    }

    // MARK: - Intervals

    /// Measures `work` as a signpost interval.
    ///
    /// - Parameters:
    ///   - name: The interval name shown in Instruments. Must be a literal.
    ///   - work: The work to measure.
    /// - Returns: Whatever `work` returns.
    @discardableResult
    public func measure<Result>(
        _ name: StaticString,
        _ work: () throws -> Result
    ) rethrows -> Result {
        guard signposter.isEnabled else { return try work() }
        return try signposter.withIntervalSignpost(name, around: work)
    }

    /// Measures an asynchronous `work` as a signpost interval.
    ///
    /// The interval spans suspension points, so it reports wall-clock elapsed time rather than
    /// CPU time — which is what you want when asking whether a step missed its frame.
    @discardableResult
    public func measure<Result>(
        _ name: StaticString,
        _ work: () async throws -> Result
    ) async rethrows -> Result {
        guard signposter.isEnabled else { return try await work() }
        // `withIntervalSignpost` has no async overload, so the interval is opened and closed by
        // hand. A fresh signpost ID keeps concurrently running intervals from being paired up with
        // one another, which the default `.exclusive` ID would do.
        let state = signposter.beginInterval(name, id: signposter.makeSignpostID())
        defer { signposter.endInterval(name, state) }
        return try await work()
    }

    /// Begins an interval that ``end(_:_:)`` closes later.
    ///
    /// Prefer ``measure(_:_:)`` when the work is lexically scoped. Use this pair when the start and
    /// end are driven by separate callbacks — a gesture beginning and settling, for example.
    ///
    /// - Returns: The state to hand back to ``end(_:_:)``, or `nil` when signposts are disabled.
    public func begin(_ name: StaticString) -> OSSignpostIntervalState? {
        guard signposter.isEnabled else { return nil }
        return signposter.beginInterval(name, id: signposter.makeSignpostID())
    }

    /// Closes an interval opened by ``begin(_:)``. A `nil` state is ignored.
    public func end(_ name: StaticString, _ state: OSSignpostIntervalState?) {
        guard let state else { return }
        signposter.endInterval(name, state)
    }

    // MARK: - Events

    /// Emits a zero-length signpost, marking a discrete moment on the timeline.
    public func event(_ name: StaticString) {
        guard signposter.isEnabled else { return }
        signposter.emitEvent(name)
    }
}
