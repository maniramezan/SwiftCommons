import Testing

@testable import SwiftCommons

@Suite("LoadingState")
struct LoadingStateTests {
    @Test
    func idleHasNoFlagsValueOrError() {
        let state: LoadingState<Int> = .idle
        #expect(!state.isLoading)
        #expect(!state.isLoaded)
        #expect(state.value == nil)
        #expect(state.error == nil)
    }

    @Test
    func loadingReportsIsLoading() {
        let state: LoadingState<Int> = .loading
        #expect(state.isLoading)
        #expect(!state.isLoaded)
        #expect(state.value == nil)
    }

    @Test
    func loadedExposesValue() {
        let state: LoadingState<Int> = .loaded(42)
        #expect(state.isLoaded)
        #expect(!state.isLoading)
        #expect(state.value == 42)
        #expect(state.error == nil)
    }

    @Test
    func failedExposesError() {
        let error = LoadingError(message: "Nope.", isRetryable: false)
        let state: LoadingState<Int> = .failed(error)
        #expect(state.error == error)
        #expect(state.value == nil)
        #expect(!state.isLoaded)
    }

    @Test
    func isEquatable() {
        #expect(LoadingState<Int>.loaded(1) == .loaded(1))
        #expect(LoadingState<Int>.loaded(1) != .loaded(2))
        #expect(LoadingState<Int>.idle != .loading)
    }

    @Test
    func loadReturnsLoadedOnSuccess() async {
        let state = await LoadingState.load { 42 }
        #expect(state == .loaded(42))
    }

    @Test
    func loadReturnsFailedWithRedactedMessageOnThrow() async {
        struct Secret: Error { let detail = "Unauthorized access for user 1234" }

        let state = await LoadingState<Int>.load { throw Secret() }
        #expect(state.error?.message == "Something went wrong. Please try again.")
        #expect(state.value == nil)
    }
}

@Suite("LoadingError")
struct LoadingErrorTests {
    @Test
    func explicitInitKeepsMessageAndFlags() {
        let error = LoadingError(message: "Sign in.", isRetryable: false, requiresSignIn: true)
        #expect(error.message == "Sign in.")
        #expect(!error.isRetryable)
        #expect(error.requiresSignIn)
    }

    @Test
    func defaultFlags() {
        let error = LoadingError(message: "Oops.")
        #expect(error.isRetryable)
        #expect(!error.requiresSignIn)
    }

    @Test
    func initFromErrorRedactsDetails() {
        struct Secret: Error { let detail = "Unauthorized access for user 1234" }
        let error = LoadingError(from: Secret())
        #expect(error.message == "Something went wrong. Please try again.")
        #expect(!error.message.contains("Unauthorized"))
        #expect(error.isRetryable)
        #expect(!error.requiresSignIn)
    }
}
