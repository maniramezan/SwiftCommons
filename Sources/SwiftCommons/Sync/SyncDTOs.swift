import Foundation

/// Request envelope pushed to the server for one resource pass.
///
/// `Upsert` and `Delete` are the app's wire shapes for created/updated rows and
/// for deletions; the ``SyncEngine`` builds these from the adapter's
/// ``SyncResourceAdapter/makeUpserts`` and ``SyncResourceAdapter/makeDeletes``.
public nonisolated struct SyncRequestDTO<
    Upsert: Encodable & Sendable,
    Delete: Encodable & Sendable
>: Encodable, Sendable {
    /// Creates a request envelope.
    /// - Parameters:
    ///   - since: Delta cursor from the previous pass, or `nil` for a full pull.
    ///   - limit: Maximum number of server changes to return per page.
    ///   - upserts: Locally created/updated rows to push.
    ///   - deletes: Locally deleted rows to push.
    public init(since: String?, limit: Int = 100, upserts: [Upsert], deletes: [Delete]) {
        self.since = since
        self.limit = limit
        self.upserts = upserts
        self.deletes = deletes
    }

    /// Delta cursor from the previous pass, or `nil` for a full pull.
    public let since: String?
    /// Maximum number of server changes to return per page.
    public let limit: Int
    /// Locally created/updated rows to push.
    public let upserts: [Upsert]
    /// Locally deleted rows to push.
    public let deletes: [Delete]
}

/// Per-item acknowledgement of a pushed change.
///
/// The ``SyncEngine`` matches each entry to a pending row by ``key`` and applies
/// the resulting state transition.
public nonisolated struct SyncAppliedDTO: Decodable, Sendable, Equatable {
    /// Creates an acknowledgement.
    /// - Parameters:
    ///   - key: Business key matching the pushed row.
    ///   - id: Assigned server id, when the row was created.
    ///   - status: Server outcome string (`created`, `updated`, `deleted`,
    ///     `noop`, `blocked`, `rejected`).
    ///   - updatedAt: Server `updatedAt` in seconds since 1970, when available.
    ///   - reason: Human-readable reason, typically for a block or rejection.
    public init(key: String, id: Int?, status: String, updatedAt: TimeInterval?, reason: String?) {
        self.key = key
        self.id = id
        self.status = status
        self.updatedAt = updatedAt
        self.reason = reason
    }

    /// Business key matching the pushed row.
    public let key: String
    /// Assigned server id, when the row was created.
    public let id: Int?
    /// Server outcome string. See ``statusKind`` for a typed view.
    public let status: String
    /// Server `updatedAt` in seconds since 1970, when available.
    public let updatedAt: TimeInterval?
    /// Human-readable reason, typically for a block or rejection.
    public let reason: String?

    /// The typed outcome for ``status``. Unrecognized strings become ``Status/unknown(_:)``.
    public var statusKind: Status { Status(rawValue: status) }

    /// The outcome the server reported for one pushed change.
    ///
    /// The server may add outcomes over time, so decoding never fails: a string this version
    /// doesn't know is kept as ``unknown(_:)``. The engine leaves a row untouched for an
    /// unknown outcome.
    public enum Status: Hashable, Sendable, RawRepresentable {
        /// The row was created on the server.
        case created
        /// The row was updated on the server.
        case updated
        /// The row was deleted on the server.
        case deleted
        /// The server already had the pushed state.
        case noop
        /// The server blocked the change; the row waits for the app to resolve it.
        case blocked
        /// The server rejected the change.
        case rejected
        /// An outcome string this version doesn't recognize.
        case unknown(String)

        /// Creates a status from the wire string. Never fails; unrecognized strings become
        /// ``unknown(_:)``.
        public init(rawValue: String) {
            switch rawValue {
            case "created": self = .created
            case "updated": self = .updated
            case "deleted": self = .deleted
            case "noop": self = .noop
            case "blocked": self = .blocked
            case "rejected": self = .rejected
            default: self = .unknown(rawValue)
            }
        }

        /// The wire string for this status.
        public var rawValue: String {
            switch self {
            case .created: "created"
            case .updated: "updated"
            case .deleted: "deleted"
            case .noop: "noop"
            case .blocked: "blocked"
            case .rejected: "rejected"
            case .unknown(let value): value
            }
        }
    }
}

/// Whether a ``SyncResponseDTO`` page is a full snapshot or a delta.
///
/// Unrecognized strings are kept as ``unknown(_:)`` and treated as a delta page.
public nonisolated enum SyncResponseMode: Hashable, Sendable, RawRepresentable {
    /// A snapshot page: rows absent from the full snapshot are tombstoned.
    case full
    /// A delta page.
    case delta
    /// A mode string this version doesn't recognize.
    case unknown(String)

    /// Creates a mode from the wire string. Never fails.
    public init(rawValue: String) {
        switch rawValue {
        case "full": self = .full
        case "delta": self = .delta
        default: self = .unknown(rawValue)
        }
    }

    /// The wire string for this mode.
    public var rawValue: String {
        switch self {
        case .full: "full"
        case .delta: "delta"
        case .unknown(let value): value
        }
    }
}

/// Response envelope returned by the server for one resource pass.
///
/// `Change` is the app's wire shape for a server-side change. Beyond the fields
/// the ``SyncEngine`` needs, ``serverInfo`` carries app-defined passthrough
/// values (for example, quota limits) into ``SyncMetadata/serverInfo``. It is
/// decoded from a nested `serverInfo` object when present; apps whose responses
/// put such values elsewhere can instead build this envelope with the memberwise
/// initializer in their ``SyncResourceAdapter/call`` closure.
public nonisolated struct SyncResponseDTO<Change: Decodable & Sendable>: Decodable, Sendable {
    /// Creates a response envelope.
    /// - Parameters:
    ///   - syncVersion: Server sync-protocol version.
    ///   - mode: `"full"` for a snapshot page, otherwise a delta page.
    ///   - applied: Per-item acknowledgements for pushed changes.
    ///   - serverChanges: Server-side changes to ingest for this page.
    ///   - cursor: Delta cursor to send on the next pass.
    ///   - hasMore: Whether more pages remain for this pass.
    ///   - fullResyncRequired: Whether the cursor was too old and a full resync
    ///     is required.
    ///   - serverInfo: App-defined passthrough values, or `nil`.
    public init(
        syncVersion: Int,
        mode: String,
        applied: [SyncAppliedDTO],
        serverChanges: [Change],
        cursor: String?,
        hasMore: Bool,
        fullResyncRequired: Bool,
        serverInfo: [String: String]? = nil
    ) {
        self.syncVersion = syncVersion
        self.mode = mode
        self.applied = applied
        self.serverChanges = serverChanges
        self.cursor = cursor
        self.hasMore = hasMore
        self.fullResyncRequired = fullResyncRequired
        self.serverInfo = serverInfo
    }

    private enum CodingKeys: String, CodingKey {
        case syncVersion, mode, applied, serverChanges, cursor, hasMore
        case fullResyncRequired, serverInfo
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        syncVersion = try container.decode(Int.self, forKey: .syncVersion)
        mode = try container.decode(String.self, forKey: .mode)
        applied = try container.decode([SyncAppliedDTO].self, forKey: .applied)
        serverChanges = try container.decode([Change].self, forKey: .serverChanges)
        cursor = try container.decodeIfPresent(String.self, forKey: .cursor)
        hasMore = try container.decode(Bool.self, forKey: .hasMore)
        fullResyncRequired = try container.decode(Bool.self, forKey: .fullResyncRequired)
        serverInfo = try container.decodeIfPresent([String: String].self, forKey: .serverInfo)
    }

    /// Server sync-protocol version.
    public let syncVersion: Int
    /// `"full"` for a snapshot page, otherwise a delta page. See ``modeKind`` for a typed view.
    public let mode: String
    /// Per-item acknowledgements for pushed changes.
    public let applied: [SyncAppliedDTO]
    /// Server-side changes to ingest for this page.
    public let serverChanges: [Change]
    /// Delta cursor to send on the next pass.
    public let cursor: String?
    /// Whether more pages remain for this pass.
    public let hasMore: Bool
    /// Whether the cursor was too old and a full resync is required.
    public let fullResyncRequired: Bool
    /// App-defined passthrough values copied into ``SyncMetadata/serverInfo``.
    public let serverInfo: [String: String]?

    /// The typed page mode for ``mode``. Unrecognized strings become
    /// ``SyncResponseMode/unknown(_:)``.
    public var modeKind: SyncResponseMode { SyncResponseMode(rawValue: mode) }
}
