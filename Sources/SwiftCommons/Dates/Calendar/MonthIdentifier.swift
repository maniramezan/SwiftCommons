import Foundation

/// Calendar month identity, including the era and leap-month distinction.
/// Resolve this identity using a Calendar configured with the matching calendar system.
public struct MonthIdentifier: Hashable, Sendable {
    /// The calendar-specific month number.
    public let month: Int
    /// The year within the specified era.
    public let year: Int
    /// The calendar system that defines the month.
    public let calendarIdentifier: Calendar.Identifier
    /// The era containing the month.
    public let era: Int
    /// Whether this identifies an intercalary leap month.
    public let isLeapMonth: Bool

    /// Creates a month identifier. The defaults describe a Gregorian month in the common era.
    public init(
        month: Int, year: Int, calendarIdentifier: Calendar.Identifier = .gregorian,
        era: Int = 1, isLeapMonth: Bool = false
    ) {
        self.month = month
        self.year = year
        self.calendarIdentifier = calendarIdentifier
        self.era = era
        self.isLeapMonth = isLeapMonth
    }
}
