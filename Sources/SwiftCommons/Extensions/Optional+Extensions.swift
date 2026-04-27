import Foundation

extension Optional {
    /// Returns wrapped value if exists. Otherwise, the passed-in default value.
    ///
    ///     var str: String? = "some string"
    ///     print(str.ifNil("another string")) // "some string"
    ///     str = nil
    ///     print(str.ifNil("another string")) // "another string"
    ///
    /// - Parameter defaultValue: Value to use if nil
    /// - Returns: Default value is nil. Otherwise, current value.
    @inlinable
    public func ifNil(_ defaultValue: @autoclosure () -> Wrapped) -> Wrapped {
        if case .some(let wrapped) = self {
            return wrapped
        }

        return defaultValue()
    }
}
