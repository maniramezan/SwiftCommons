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
    public static func deterministicMD5(from string: String) -> UUID {
        deterministicMD5(from: Data(string.utf8))
    }

    /// Creates a stable UUID from the MD5 digest of `data`.
    ///
    /// This is intended for deterministic identifiers, not security-sensitive hashing.
    public static func deterministicMD5(from data: Data) -> UUID {
        let digest = Insecure.MD5.hash(data: data)
        return try! UUID(bytes: Array(digest))
    }
}
