import Testing

@testable import SwiftCommons

@Suite("RefreshableLoadingState")
struct RefreshableLoadingStateTests {
    @Test
    func startsIdleWithNothingToShow() {
        let state = RefreshableLoadingState<Int>()

        #expect(state.state == .idle)
        #expect(state.displayValue == nil)
        #expect(!state.isRefreshing)
        #expect(!state.isInitialLoading)
    }

    @Test
    func firstLoadIsInitialLoadingNotRefreshing() {
        var state = RefreshableLoadingState<Int>()

        state.beginLoading()

        #expect(state.isInitialLoading)
        #expect(!state.isRefreshing)
        #expect(state.displayValue == nil)
    }

    @Test
    func reloadKeepsShowingThePreviousValueUntilTheNewOneArrives() {
        var state = RefreshableLoadingState<Int>()
        state.beginLoading()
        state.finish(with: .loaded(1))

        state.beginLoading()

        #expect(state.isRefreshing)
        #expect(!state.isInitialLoading)
        #expect(state.displayValue == 1)

        state.finish(with: .loaded(2))

        #expect(!state.isRefreshing)
        #expect(state.displayValue == 2)
        #expect(state.lastValue == 2)
    }

    @Test
    func failedReloadKeepsThePreviousValueAndExposesTheError() {
        var state = RefreshableLoadingState<Int>(state: .loaded(5))
        let failure = LoadingError(message: "No network.", kind: .offline)

        state.beginLoading()
        state.finish(with: .failed(failure))

        #expect(state.error == failure)
        #expect(state.displayValue == 5)
    }

    @Test
    func cancelledReloadReturnsToIdleButKeepsThePreviousValue() {
        var state = RefreshableLoadingState<Int>(state: .loaded(5))

        state.beginLoading()
        state.finish(with: .idle)

        #expect(state.state == .idle)
        #expect(state.displayValue == 5)
    }

    @Test
    func initializingFromALoadedStateRemembersItsValue() {
        let state = RefreshableLoadingState(state: LoadingState<Int>.loaded(9))

        #expect(state.lastValue == 9)
        #expect(state.displayValue == 9)
    }

    @Test
    func finishWithLoadWorksEndToEnd() async {
        var state = RefreshableLoadingState<Int>()

        state.beginLoading()
        state.finish(with: await .load { 7 })

        #expect(state.displayValue == 7)
    }
}
