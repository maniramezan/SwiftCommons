import SwiftCommonsTestSupport
import Testing

@Test func cancellingManualClockSleepRemovesWaiter() async throws {
    let clock = ManualClock()
    let task = Task { try await clock.sleep(for: .seconds(60)) }
    // Wait for registration so this verifies cancellation of a suspended sleep.
    while await clock.waiterCount == 0 { await Task.yield() }
    task.cancel()
    await #expect(throws: CancellationError.self) { try await task.value }
    #expect(await clock.waiterCount == 0)
    await clock.advance(by: .seconds(60))
}

@Test func alreadyCancelledManualClockSleepDoesNotRegister() async {
    let clock = ManualClock()
    let task = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        try await clock.sleep(for: .zero)
    }
    await #expect(throws: CancellationError.self) { try await task.value }
    #expect(await clock.waiterCount == 0)
}
