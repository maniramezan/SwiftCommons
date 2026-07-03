import Testing

@testable import SwiftCommonsTestSupport

@Suite("Box and recordingCall")
struct BoxTests {
    @Test
    @MainActor
    func boxReadsAndWritesValue() {
        let box = Box(1)
        #expect(box.value == 1)
        box.value = 2
        #expect(box.value == 2)
    }

    @Test
    func recordingCallAppendsEachRequestAndReturnsTheFixedResponse() async throws {
        let requests = await Box<[String]>([])
        let call: @Sendable (String) async throws -> String = recordingCall(
            returning: "response", into: requests)

        let first = try await call("request-1")
        let second = try await call("request-2")

        #expect(first == "response")
        #expect(second == "response")
        #expect(await requests.value == ["request-1", "request-2"])
    }
}
