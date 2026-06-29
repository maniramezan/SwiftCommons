import Foundation
import Testing

@testable import SwiftCommons

@Suite("UUID extensions")
struct UUIDExtensionsTests {
    @Test
    func bytesExposeCanonicalByteOrder() throws {
        let uuid = try #require(UUID(uuidString: "00112233-4455-6677-8899-aabbccddeeff"))

        #expect(
            uuid.bytes == [
                0x00, 0x11, 0x22, 0x33,
                0x44, 0x55, 0x66, 0x77,
                0x88, 0x99, 0xaa, 0xbb,
                0xcc, 0xdd, 0xee, 0xff,
            ])
    }

    @Test
    func initFromBytesRoundTrips() throws {
        let bytes: [UInt8] = [
            0x00, 0x11, 0x22, 0x33,
            0x44, 0x55, 0x66, 0x77,
            0x88, 0x99, 0xaa, 0xbb,
            0xcc, 0xdd, 0xee, 0xff,
        ]

        let uuid = try UUID(bytes: bytes)

        #expect(uuid.uuidString.lowercased() == "00112233-4455-6677-8899-aabbccddeeff")
    }

    @Test
    func initFromBytesRejectsInvalidCounts() {
        #expect(throws: UUID.UUIDError.invalidByteCount(15)) {
            try UUID(bytes: Array(repeating: UInt8(0), count: 15))
        }
        #expect(throws: UUID.UUIDError.invalidByteCount(17)) {
            try UUID(bytes: Array(repeating: UInt8(0), count: 17))
        }
    }

    @Test
    func deterministicMD5FromStringIsStable() throws {
        let uuid = UUID.deterministicMD5(from: "SwiftCommons")

        #expect(uuid == UUID.deterministicMD5(from: "SwiftCommons"))
        #expect(uuid != UUID.deterministicMD5(from: "swiftcommons"))
        #expect(uuid.uuidString.lowercased() == "1bbe5762-47cc-0c21-603d-57e1748415b4")
    }

    @Test
    func deterministicMD5FromDataMatchesStringInput() {
        let stringUUID = UUID.deterministicMD5(from: "SwiftCommons")
        let dataUUID = UUID.deterministicMD5(from: Data("SwiftCommons".utf8))

        #expect(dataUUID == stringUUID)
    }
}
