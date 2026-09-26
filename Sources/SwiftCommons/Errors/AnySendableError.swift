import Foundation

/// A value snapshot of any `Error`: its type name, `NSError` domain and code, description, and
/// localized description.
///
/// Wrap an arbitrary error when it has to be stored, compared, or passed around as a plain value,
/// for example as the payload of your own `Equatable` error enum:
///
///     enum SyncError: Error, Hashable {
///         case decodingFailed(AnySendableError)
///     }
///
///     do {
///         _ = try JSONDecoder().decode(Item.self, from: data)
///     } catch {
///         throw SyncError.decodingFailed(AnySendableError(error))
///     }
///
/// The original error isn't retained, only the captured strings and code, so the snapshot is
/// `Sendable` and `Hashable` whatever the original error holds. Downcasting it back to the
/// original type isn't possible; match on ``domain`` and ``code`` instead.
///
/// `localizedDescription` returns the original error's localized description. When bridged to
/// `NSError`, the domain is this type's own. Read ``domain`` and ``code`` for the original
/// values. `Logger.error(_:error:context:)` logs the original type, domain, and code.
public struct AnySendableError: Error, Hashable, CustomStringConvertible, LocalizedError {
    /// The fully qualified type name of the original error, e.g. `Swift.DecodingError`.
    public let typeName: String

    /// The original error's `NSError` domain, e.g. `NSURLErrorDomain`.
    public let domain: String

    /// The original error's `NSError` code, e.g. `-1009`.
    public let code: Int

    /// `String(describing:)` of the original error.
    ///
    /// This can include user data (paths, values), so log it privately.
    public let description: String

    private let capturedLocalizedDescription: String

    /// Captures a snapshot of `error`.
    ///
    /// Wrapping an `AnySendableError` returns an equal copy rather than nesting it.
    ///
    /// - Parameter error: The error to capture.
    public init(_ error: any Error) {
        if let alreadyWrapped = error as? AnySendableError {
            self = alreadyWrapped
            return
        }
        let nsError = error as NSError
        typeName = String(reflecting: type(of: error))
        domain = nsError.domain
        code = nsError.code
        description = String(describing: error)
        capturedLocalizedDescription = error.localizedDescription
    }

    /// The original error's `localizedDescription`.
    public var errorDescription: String? {
        capturedLocalizedDescription
    }
}
