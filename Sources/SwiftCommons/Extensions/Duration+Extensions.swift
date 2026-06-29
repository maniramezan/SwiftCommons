import Foundation

extension Duration {
    /// The duration expressed in seconds for APIs that take `TimeInterval`.
    public var timeInterval: TimeInterval {
        let components = self.components
        return TimeInterval(components.seconds) + TimeInterval(components.attoseconds) / 1e18
    }
}
