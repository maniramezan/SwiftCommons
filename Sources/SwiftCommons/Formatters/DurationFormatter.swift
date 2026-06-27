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
    ///   formatted using their truncated components and are not recommended.
    /// - Returns: The formatted duration string.
    public static func format(seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60

        return if hours > 0 {
            String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
        } else {
            String(format: "%d:%02d", minutes, remainingSeconds)
        }
    }
}
