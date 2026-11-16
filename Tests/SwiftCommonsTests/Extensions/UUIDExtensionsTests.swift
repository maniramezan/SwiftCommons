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

    @Test(arguments: [
        (UUID.dnsNamespace, "6ba7b810-9dad-11d1-80b4-00c04fd430c8"),
        (UUID.urlNamespace, "6ba7b811-9dad-11d1-80b4-00c04fd430c8"),
        (UUID.oidNamespace, "6ba7b812-9dad-11d1-80b4-00c04fd430c8"),
        (UUID.x500Namespace, "6ba7b814-9dad-11d1-80b4-00c04fd430c8"),
    ])
    func predefinedNamespacesMatchRFC4122(namespace: UUID, expected: String) {
        #expect(namespace.uuidString.lowercased() == expected)
    }

    @Test(arguments: [
        (UUID.dnsNamespace, "python.org", "886313e1-3b8a-5372-9b90-0c9aee199e5d"),
        (UUID.urlNamespace, "https://example.com/a", "6639460f-3425-5329-8097-a58f06127860"),
        (UUID.dnsNamespace, "", "4ebd0208-8328-5d69-8c44-ec50939c0967"),
    ])
    func namespaceAndNameMatchesReferenceVersion5Vectors(
        namespace: UUID, name: String, expected: String
    ) {
        #expect(UUID(namespace: namespace, name: name).uuidString.lowercased() == expected)
    }

    @Test
    func namespaceUUIDSetsVersion5AndTheRFCVariant() {
        let bytes = UUID(namespace: .dnsNamespace, name: "SwiftCommons").bytes

        #expect(bytes[6] >> 4 == 5)
        #expect(bytes[8] >> 6 == 0b10)
    }

    @Test
    func namespaceUUIDDiffersByNamespaceAndNameAndIsStable() {
        let first = UUID(namespace: .dnsNamespace, name: "SwiftCommons")

        #expect(first == UUID(namespace: .dnsNamespace, name: "SwiftCommons"))
        #expect(first != UUID(namespace: .urlNamespace, name: "SwiftCommons"))
        #expect(first != UUID(namespace: .dnsNamespace, name: "swiftcommons"))
    }

    @Test
    func namespaceUUIDFromDataMatchesStringInput() {
        let fromString = UUID(namespace: .urlNamespace, name: "héllo")
        let fromData = UUID(namespace: .urlNamespace, name: Data("héllo".utf8))

        #expect(fromData == fromString)
    }

    @Test
    func deterministicMD5RemainsNonStandardAndUnchanged() {
        let bytes = UUID.deterministicMD5(from: "SwiftCommons").bytes

        // Stored identifiers depend on this output, so it must never gain version bits.
        #expect(bytes[6] >> 4 != 3)
        #expect(
            UUID.deterministicMD5(from: "SwiftCommons").uuidString.lowercased()
                == "1bbe5762-47cc-0c21-603d-57e1748415b4")
    }
}
