import Foundation
import Testing

@testable import SwiftCommons

@Suite("AnySendableError")
struct AnySendableErrorTests {
    private enum SampleError: Error, CustomStringConvertible {
        case missingRecord(id: Int)

        var description: String {
            switch self {
            case .missingRecord(let id): "missing record \(id)"
            }
        }
    }

    private struct DescribedError: LocalizedError {
        var errorDescription: String? { "Something user-facing went wrong." }
    }

    @Test
    func capturesDomainAndCodeOfAnNSError() {
        let snapshot = AnySendableError(URLError(.notConnectedToInternet))

        #expect(snapshot.domain == NSURLErrorDomain)
        #expect(snapshot.code == -1009)
    }

    @Test
    func capturesTypeNameAndDescriptionOfASwiftError() {
        let original = SampleError.missingRecord(id: 7)
        let snapshot = AnySendableError(original)

        #expect(snapshot.typeName.hasPrefix("SwiftCommonsTests.AnySendableErrorTests."))
        #expect(snapshot.typeName.hasSuffix(".SampleError"))
        #expect(snapshot.description == "missing record 7")
        #expect(snapshot.domain == (original as NSError).domain)
        #expect(snapshot.code == (original as NSError).code)
    }

    @Test
    func localizedDescriptionMatchesTheOriginalThroughAnyError() {
        let original = DescribedError()
        let erased: any Error = AnySendableError(original)

        #expect(erased.localizedDescription == "Something user-facing went wrong.")
        #expect(erased.localizedDescription == original.localizedDescription)
    }

    @Test
    func wrappingASnapshotDoesNotNestIt() {
        let snapshot = AnySendableError(URLError(.timedOut))
        let rewrapped = AnySendableError(snapshot)

        #expect(rewrapped == snapshot)
        #expect(!rewrapped.typeName.hasSuffix("AnySendableError"))
        #expect(rewrapped.domain == NSURLErrorDomain)
    }

    @Test
    func snapshotsOfEquivalentErrorsAreEqual() {
        #expect(AnySendableError(URLError(.timedOut)) == AnySendableError(URLError(.timedOut)))
        #expect(
            AnySendableError(URLError(.timedOut))
                != AnySendableError(URLError(.notConnectedToInternet)))
    }
}
