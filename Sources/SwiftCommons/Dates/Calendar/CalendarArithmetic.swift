import Foundation

/// Calendar arithmetic preserving era and leap-month identity, without application date limits.
public struct CalendarArithmetic: Sendable {
    /// The calendar used to resolve month identities and dates, including its time zone.
    public let calendar: Calendar

    /// Creates arithmetic using the supplied calendar configuration.
    public init(calendar: Calendar) {
        self.calendar = calendar
    }

    /// Returns the identity of the month containing a date.
    public func month(containing date: Date) -> MonthIdentifier {
        let start = calendar.dateInterval(of: .month, for: date)?.start ?? date
        let components = calendar.dateComponents([.era, .year, .month], from: start)
        return MonthIdentifier(
            month: components.month ?? 1, year: components.year ?? 1,
            calendarIdentifier: calendar.identifier, era: components.era ?? 1,
            isLeapMonth: components.isLeapMonth ?? false
        )
    }

    /// Resolves a valid month identity, or returns nil for a mismatched or invalid identity.
    public func start(of month: MonthIdentifier) -> Date? {
        guard month.calendarIdentifier == calendar.identifier else { return nil }
        var components = DateComponents(
            era: month.era, year: month.year, month: month.month, day: 1)
        components.isLeapMonth = month.isLeapMonth
        guard let date = calendar.date(from: components), self.month(containing: date) == month
        else {
            return nil
        }
        return calendar.dateInterval(of: .month, for: date)?.start
    }

    /// Returns the interval for a valid month identity.
    public func interval(of month: MonthIdentifier) -> DateInterval? {
        guard let start = start(of: month) else { return nil }
        return calendar.dateInterval(of: .month, for: start)
    }

    /// Returns a date for a day in the month, or nil when the day or month is invalid.
    public func date(day: Int, in month: MonthIdentifier) -> Date? {
        guard let start = start(of: month),
            let days = calendar.range(of: .day, in: .month, for: start), days.contains(day)
        else { return nil }
        return calendar.date(byAdding: .day, value: day - 1, to: start)
    }

    /// Returns a relative month without imposing an application date range.
    public func month(offset: Int, from month: MonthIdentifier) -> MonthIdentifier? {
        guard let start = start(of: month),
            let date = calendar.date(byAdding: .month, value: offset, to: start)
        else { return nil }
        return self.month(containing: date)
    }

    /// Lists months in a positive year within the era containing the reference date.
    public func months(in year: Int, relativeTo reference: Date) -> [MonthIdentifier] {
        guard year > 0 else { return [] }
        let era = calendar.component(.era, from: reference)
        guard
            let seed = calendar.date(from: DateComponents(era: era, year: year, month: 1, day: 1)),
            let yearInterval = calendar.dateInterval(of: .year, for: seed)
        else { return [] }
        let eraInterval = calendar.dateInterval(of: .era, for: reference)
        let start = max(yearInterval.start, eraInterval?.start ?? yearInterval.start)
        let end = min(yearInterval.end, eraInterval?.end ?? yearInterval.end)
        guard start < end, calendar.component(.year, from: start) == year else { return [] }
        var result: [MonthIdentifier] = []
        var cursor = start
        while cursor < end {
            guard let interval = calendar.dateInterval(of: .month, for: cursor),
                interval.end > cursor
            else {
                break
            }
            result.append(month(containing: cursor))
            cursor = interval.end
        }
        return result
    }
}
