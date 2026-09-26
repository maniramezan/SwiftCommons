import Foundation
import Testing

@testable import SwiftCommons

@Suite("DecodingError+Extensions")
struct DecodingErrorExtensionsTests {
    private struct Feed: Decodable {
        let items: [Item]
    }

    private struct Item: Decodable {
        let user: User
    }

    private struct User: Decodable {
        let id: Int
        let name: String
    }

    private enum Status: String, Decodable {
        case active
    }

    private struct Account: Decodable {
        let status: Status
    }

    private struct NumberedKeys: Decodable {
        let id: Int

        enum CodingKeys: Int, CodingKey {
            case id = 7
        }
    }

    @Test
    func keyNotFoundNamesTheKeyAndItsContainer() throws {
        let json =
            #"{"items": [{"user": {"id": 1, "name": "a"}}, {"user": {"id": 2, "name": "b"}}, {"user": {"name": "c"}}]}"#
        let error = try decodingError(Feed.self, from: json)
        #expect(error.debugSummary == "keyNotFound 'id' at items[2].user")
    }

    @Test
    func typeMismatchNamesTheExpectedTypeAndFullPath() throws {
        let json = #"{"items": [{"user": {"id": "one", "name": "a"}}]}"#
        let error = try decodingError(Feed.self, from: json)
        #expect(error.debugSummary == "typeMismatch Int at items[0].user.id")
    }

    @Test
    func valueNotFoundNamesTheExpectedTypeAndFullPath() throws {
        let json = #"{"items": [{"user": {"id": 1, "name": null}}]}"#
        let error = try decodingError(Feed.self, from: json)
        #expect(error.debugSummary == "valueNotFound String at items[0].user.name")
    }

    @Test
    func dataCorruptedOmitsTheInvalidValue() throws {
        let json = #"{"status": "secret-value"}"#
        let error = try decodingError(Account.self, from: json)
        #expect(error.debugSummary == "dataCorrupted at status")
        #expect(!error.debugSummary.contains("secret-value"))
    }

    @Test
    func topLevelFailureReportsTheRoot() throws {
        let error = try decodingError(Feed.self, from: "not json")
        #expect(error.debugSummary == "dataCorrupted at <root>")

        let nullError = try decodingError(String.self, from: "null")
        #expect(nullError.debugSummary == "valueNotFound String at <root>")
    }

    @Test
    func intBackedCodingKeysKeepTheirNames() throws {
        let error = try decodingError(NumberedKeys.self, from: #"{"id": "seven"}"#)
        #expect(error.debugSummary == "typeMismatch Int at id")
    }

    @Test
    func handBuiltErrorsUseTheSameFormat() {
        let context = DecodingError.Context(codingPath: [], debugDescription: "anything")
        #expect(DecodingError.dataCorrupted(context).debugSummary == "dataCorrupted at <root>")
        #expect(
            DecodingError.keyNotFound(NumberedKeys.CodingKeys.id, context).debugSummary
                == "keyNotFound 'id' at <root>")
    }

    private func decodingError<Value: Decodable>(
        _ type: Value.Type, from json: String
    ) throws -> DecodingError {
        do {
            _ = try JSONDecoder().decode(type, from: Data(json.utf8))
        } catch let error as DecodingError {
            return error
        }
        Issue.record("Expected decoding \(type) to fail")
        throw CancellationError()
    }
}
