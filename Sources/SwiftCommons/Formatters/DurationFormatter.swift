import Foundation

/// Formats a whole number of seconds into a compact, human-readable duration.
public enum DurationFormatter {
    /// Formats seconds into a readable duration string.
    ///
    ///     DurationFormatter.format(seconds: 225)  // "3:45"
    ///     DurationFormatter.format(seconds: 3750) // "1:02:30"
    ///
    /// When the duration is under an hour the result is `m:ss`; once it reaches
    /// an hour or more the hour component is prepended as `h:mm:ss`.
    ///
    /// - Parameter seconds: The duration in seconds. Negative values are
    ///   formatted with a leading minus sign.
    /// - Returns: The formatted duration string.
    public static func format(seconds: Int) -> String {
        let magnitude = seconds.magnitude
        let hours = magnitude / 3600
        let minutes = (magnitude % 3600) / 60
        let remainingSeconds = magnitude % 60
        let sign = seconds < 0 ? "-" : ""

        return if hours > 0 {
            "\(sign)\(hours):\(twoDigits(minutes)):\(twoDigits(remainingSeconds))"
        } else {
            "\(sign)\(minutes):\(twoDigits(remainingSeconds))"
        }
    }

    /// Zero-pads a value in `0...59` to two digits without going through `String(format:)`.
    private static func twoDigits(_ value: UInt) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }
}
