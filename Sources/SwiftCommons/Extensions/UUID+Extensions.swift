import CryptoKit
import Foundation

extension UUID {
    /// Errors thrown while constructing UUID values.
    public enum UUIDError: Error, Equatable, Sendable {
        /// UUIDs require exactly 16 bytes.
        case invalidByteCount(Int)
    }

    /// The UUID's 16 bytes in canonical order.
    public var bytes: [UInt8] {
        [
            uuid.0, uuid.1, uuid.2, uuid.3,
            uuid.4, uuid.5, uuid.6, uuid.7,
            uuid.8, uuid.9, uuid.10, uuid.11,
            uuid.12, uuid.13, uuid.14, uuid.15,
        ]
    }

    /// Creates a UUID from exactly 16 bytes in canonical order.
    public init(bytes: some Collection<UInt8>) throws {
        guard bytes.count == 16 else {
            throw UUIDError.invalidByteCount(bytes.count)
        }

        let bytes = Array(bytes)
        self.init(
            uuid: (
                bytes[0], bytes[1], bytes[2], bytes[3],
                bytes[4], bytes[5], bytes[6], bytes[7],
                bytes[8], bytes[9], bytes[10], bytes[11],
                bytes[12], bytes[13], bytes[14], bytes[15]
            )
        )
    }

    /// Creates a stable UUID from the MD5 digest of `string`.
    ///
    /// This is intended for deterministic identifiers, not security-sensitive hashing.
    ///
    /// The result is **not** an RFC 4122 name-based (version 3) UUID: the 16 digest bytes are
    /// used as-is, with no namespace and no version or variant bits. Its output is kept stable
    /// because identifiers derived from it may already be stored. For a standards-compliant
    /// name-based UUID, use ``init(namespace:name:)``.
    public static func deterministicMD5(from string: String) -> UUID {
        deterministicMD5(from: Data(string.utf8))
    }

    /// Creates a stable UUID from the MD5 digest of `data`.
    ///
    /// This is intended for deterministic identifiers, not security-sensitive hashing. Like
    /// ``deterministicMD5(from:)-(String)``, the result is not an RFC 4122 version 3 UUID.
    public static func deterministicMD5(from data: Data) -> UUID {
        let digest = Array(Insecure.MD5.hash(data: data))
        return UUID(
            uuid: (
                digest[0], digest[1], digest[2], digest[3],
                digest[4], digest[5], digest[6], digest[7],
                digest[8], digest[9], digest[10], digest[11],
                digest[12], digest[13], digest[14], digest[15]
            )
        )
    }

    /// The RFC 4122 namespace for fully qualified domain names (`6ba7b810-9dad-11d1-80b4-00c04fd430c8`).
    public static let dnsNamespace = UUID(
        uuid: (
            0x6b, 0xa7, 0xb8, 0x10, 0x9d, 0xad, 0x11, 0xd1,
            0x80, 0xb4, 0x00, 0xc0, 0x4f, 0xd4, 0x30, 0xc8
        ))

    /// The RFC 4122 namespace for URLs (`6ba7b811-9dad-11d1-80b4-00c04fd430c8`).
    public static let urlNamespace = UUID(
        uuid: (
            0x6b, 0xa7, 0xb8, 0x11, 0x9d, 0xad, 0x11, 0xd1,
            0x80, 0xb4, 0x00, 0xc0, 0x4f, 0xd4, 0x30, 0xc8
        ))

    /// The RFC 4122 namespace for ISO OIDs (`6ba7b812-9dad-11d1-80b4-00c04fd430c8`).
    public static let oidNamespace = UUID(
        uuid: (
            0x6b, 0xa7, 0xb8, 0x12, 0x9d, 0xad, 0x11, 0xd1,
            0x80, 0xb4, 0x00, 0xc0, 0x4f, 0xd4, 0x30, 0xc8
        ))

    /// The RFC 4122 namespace for X.500 distinguished names (`6ba7b814-9dad-11d1-80b4-00c04fd430c8`).
    public static let x500Namespace = UUID(
        uuid: (
            0x6b, 0xa7, 0xb8, 0x14, 0x9d, 0xad, 0x11, 0xd1,
            0x80, 0xb4, 0x00, 0xc0, 0x4f, 0xd4, 0x30, 0xc8
        ))

    /// Creates an RFC 4122 name-based UUID (version 5, SHA-1) from a namespace and a name.
    ///
    ///     let id = UUID(namespace: .dnsNamespace, name: "python.org")
    ///     // 886313e1-3b8a-5372-9b90-0c9aee199e5d
    ///
    /// The same namespace and name always produce the same UUID, on any platform and in any
    /// other RFC 4122 implementation. Use a namespace of your own (a fixed, randomly generated
    /// UUID) to keep your identifiers separate from everyone else's, or one of the predefined
    /// ``dnsNamespace``, ``urlNamespace``, ``oidNamespace`` and ``x500Namespace``.
    ///
    /// Not for security-sensitive hashing: SHA-1 is used because the standard requires it.
    /// - Parameters:
    ///   - namespace: The namespace UUID.
    ///   - name: The name, encoded as UTF-8.
    public init(namespace: UUID, name: String) {
        self.init(namespace: namespace, name: Data(name.utf8))
    }

    /// Creates an RFC 4122 name-based UUID (version 5, SHA-1) from a namespace and name bytes.
    ///
    /// - Parameters:
    ///   - namespace: The namespace UUID.
    ///   - name: The name's bytes.
    public init(namespace: UUID, name: Data) {
        var hasher = Insecure.SHA1()
        hasher.update(data: Data(namespace.bytes))
        hasher.update(data: name)
        var digest = Array(hasher.finalize().prefix(16))
        // Version 5 in the high nibble of byte 6, RFC 4122 variant (10xx) in byte 8.
        digest[6] = (digest[6] & 0x0F) | 0x50
        digest[8] = (digest[8] & 0x3F) | 0x80
        self.init(
            uuid: (
                digest[0], digest[1], digest[2], digest[3],
                digest[4], digest[5], digest[6], digest[7],
                digest[8], digest[9], digest[10], digest[11],
                digest[12], digest[13], digest[14], digest[15]
            )
        )
    }
}
