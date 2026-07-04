import Testing

@testable import SwiftCommons
@testable import SwiftCommonsTestSupport

@Suite("LoadingState assertions")
struct LoadingStateAssertionsTests {
    @Test
    func expectLoadedReturnsValueWhenLoaded() {
        let state: LoadingState<Int> = .loaded(42)
        #expect(expectLoaded(state) == 42)
    }

    @Test
    func expectFailedReturnsErrorWhenFailed() {
        let error = LoadingError(message: "Nope.", isRetryable: false)
        let state: LoadingState<Int> = .failed(error)
        #expect(expectFailed(state) == error)
    }
}
