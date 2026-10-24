import Foundation
import SwiftCommons
import Testing

@Suite("Loading error classification")
struct LoadingErrorClassificationTests {
    private struct ServiceError: Error, LocalizedError, LoadingErrorClassifiable {
        let loadingErrorKind: LoadingErrorKind
        var errorDescription: String? { "Internal service details" }
    }

    @Test(arguments: [
        (
            LoadingErrorKind.offline,
            "Unable to connect. Please check your internet connection and try again."
        ),
        (.timedOut, "The request timed out. Please try again."),
        (.other, "Something went wrong. Please try again."),
    ])
    func usesSafeCategoryMessages(kind: LoadingErrorKind, message: String) async {
        let error = ServiceError(loadingErrorKind: kind)
        let state = await LoadingState<Int>.load { throw error }
        #expect(state.error?.kind == kind)
        #expect(state.error?.message == message)
        #expect(state.error?.isRetryable == true)
        #expect(state.error?.requiresSignIn == false)
        #expect(state.error?.message.contains("Internal") == false)
    }

    @Test(arguments: [
        (URLError.Code.notConnectedToInternet, LoadingErrorKind.offline),
        (.timedOut, .timedOut),
        (.badServerResponse, .other),
    ])
    func classifiesFoundationErrors(code: URLError.Code, kind: LoadingErrorKind) {
        #expect(LoadingError(from: URLError(code)).kind == kind)
    }

    @Test func classifiesTimeoutError() {
        let error = LoadingError(from: TimeoutError())
        #expect(error.kind == .timedOut)
        #expect(error.message == "The request timed out. Please try again.")
    }

    @Test func unknownErrorKeepsGenericPresentation() {
        struct UnknownError: Error {}
        let error = LoadingError(from: UnknownError())
        #expect(error.kind == .other)
        #expect(error.message == "Something went wrong. Please try again.")
    }

    @Test func explicitMessageAndFlagsArePreserved() {
        let error = LoadingError(
            message: "Custom localized message", isRetryable: false, requiresSignIn: true,
            kind: .offline)
        #expect(error.kind == .offline)
        #expect(error.message == "Custom localized message")
        #expect(!error.isRetryable)
        #expect(error.requiresSignIn)
        #expect(LoadingError(message: "Custom localized message").kind == .other)
    }

    @Test func classificationParticipatesInEquality() {
        #expect(
            LoadingError(message: "Try again", kind: .offline)
                != LoadingError(message: "Try again", kind: .timedOut))
    }
}
