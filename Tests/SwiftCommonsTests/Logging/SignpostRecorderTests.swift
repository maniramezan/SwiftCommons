import OSLog
import Testing

@testable import SwiftCommons

@Suite("SignpostRecorder Tests")
struct SignpostRecorderTests {

    @Test("measure returns the work's value")
    func measureReturnsValue() {
        let recorder = SignpostRecorder(subsystem: "SwiftCommonsTests", category: "Rendering")

        let result = recorder.measure("unit") { 21 * 2 }

        #expect(result == 42)
    }

    @Test("measure rethrows the work's error")
    func measureRethrows() {
        struct Failure: Error {}
        let recorder = SignpostRecorder(subsystem: "SwiftCommonsTests", category: "Rendering")

        #expect(throws: Failure.self) {
            try recorder.measure("unit") { throw Failure() }
        }
    }

    @Test("async measure returns the work's value")
    func asyncMeasureReturnsValue() async {
        let recorder = SignpostRecorder(subsystem: "SwiftCommonsTests", category: "Rendering")

        let result = await recorder.measure("unit") {
            await Task.yield()
            return "done"
        }

        #expect(result == "done")
    }

    @Test("begin and end tolerate a disabled signposter")
    func beginEndTolerateDisabledSignposter() {
        let recorder = SignpostRecorder(subsystem: "SwiftCommonsTests", category: "Rendering")

        let state = recorder.begin("unit")
        recorder.end("unit", state)
        recorder.end("unit", nil)
    }

    @Test("event and isEnabled are safe to call without a profiler attached")
    func eventIsSafeWithoutProfiler() {
        let recorder = SignpostRecorder.swiftCommons(category: "Rendering")

        recorder.event("unit")

        #expect(recorder.signposter.isEnabled == recorder.isEnabled)
    }

    @Test("signposter initializer reuses the supplied signposter")
    func signposterInitializerReusesSignposter() {
        let signposter = OSSignposter(subsystem: "SwiftCommonsTests", category: "Reuse")
        let recorder = SignpostRecorder(signposter: signposter)

        #expect(recorder.isEnabled == signposter.isEnabled)
    }
}
