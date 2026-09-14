import Foundation

/// Calendar arithmetic preserving era and leap-month identity, without application date limits.
///
/// A month split by an era change (for example January 1989, Showa 64 then Heisei 1) is treated
/// as two months, each covering only the days inside its own era.
public struct CalendarArithmetic: Sendable {
    /// The calendar used to resolve month identities and dates, including its time zone.
    public let calendar: Calendar

    /// Creates arithmetic using the supplied calendar configuration.
    public init(calendar: Calendar) {
        self.calendar = calendar
    }

    /// Whether this calendar system can have an era boundary fall in the middle of a month.
    ///
    /// Every era-splitting code path below costs a handful of extra `Calendar` calls per
    /// invocation over the simple, non-splitting arithmetic — real overhead when `month(containing:)`
    /// runs on every realized row of a scrolling calendar. Only Japan's imperial eras change on an
    /// arbitrary day (a new emperor's accession), so every other calendar system — including ones
    /// with their own single, fixed era (Hebrew AM, Islamic AH, Buddhist BE, ...) — can skip that
    /// work entirely and use the cheaper path a normal (non-era-splitting) month lookup needs.
    private var canSplitAcrossEra: Bool {
        calendar.identifier == .japanese
    }

    /// Returns the identity of the month containing a date.
    public func month(containing date: Date) -> MonthIdentifier {
        let start: Date
        if canSplitAcrossEra {
            start = segmentStart(for: date) ?? date
        } else {
            start = calendar.dateInterval(of: .month, for: date)?.start ?? date
        }
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
        guard let date = calendar.date(from: components),
            let monthInterval = calendar.dateInterval(of: .month, for: date)
        else { return nil }
        guard canSplitAcrossEra else {
            return self.month(containing: monthInterval.start) == month ? monthInterval.start : nil
        }
        // Day 1 of a month whose era began mid-month resolves into the previous era, so also try
        // the era segment that ends the month.
        guard let lastDay = calendar.date(byAdding: .day, value: -1, to: monthInterval.end)
        else { return nil }
        return [monthInterval.start, segmentStart(for: lastDay)]
            .compactMap { $0 }
            .first { self.month(containing: $0) == month }
    }

    /// Returns the interval for a valid month identity, limited to the days in its era.
    public func interval(of month: MonthIdentifier) -> DateInterval? {
        guard let start = start(of: month),
            let monthEnd = calendar.dateInterval(of: .month, for: start)?.end
        else { return nil }
        guard canSplitAcrossEra else {
            return DateInterval(start: start, end: monthEnd)
        }
        guard let lastDay = calendar.date(byAdding: .day, value: -1, to: monthEnd) else {
            return nil
        }
        let era = calendar.component(.era, from: start)
        guard calendar.component(.era, from: lastDay) != era else {
            return DateInterval(start: start, end: monthEnd)
        }
        var day = start
        while let next = calendar.date(byAdding: .day, value: 1, to: day), next < monthEnd {
            if calendar.component(.era, from: next) != era {
                return DateInterval(start: start, end: next)
            }
            day = next
        }
        return DateInterval(start: start, end: monthEnd)
    }

    /// Returns a date for a day in the month, or nil when the day or month is invalid.
    public func date(day: Int, in month: MonthIdentifier) -> Date? {
        guard let interval = interval(of: month),
            let monthStart = calendar.dateInterval(of: .month, for: interval.start)?.start,
            let days = calendar.range(of: .day, in: .month, for: monthStart), days.contains(day),
            let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart),
            date >= interval.start, date < interval.end
        else { return nil }
        return date
    }

    /// Returns a relative month without imposing an application date range.
    ///
    /// A single step (`offset` of 1 or -1) crosses to the adjacent month via `month`'s own
    /// interval boundary rather than adding a calendar month to day 1. For most months these
    /// agree, but a month whose era began mid-month (see the type documentation) starts after day
    /// 1 of its underlying Gregorian month — adding or subtracting a whole calendar month from
    /// that day 1 lands on the *other* era's segment of the same Gregorian month, skipping the
    /// adjacent split segment entirely. Larger offsets keep the calendar-month arithmetic: they
    /// only need to land in the right neighborhood, and boundary-walking every step would turn a
    /// bulk lookup (a scrolling calendar can realize thousands of offsets from one anchor) into
    /// O(offset) work instead of O(1).
    public func month(offset: Int, from month: MonthIdentifier) -> MonthIdentifier? {
        switch offset {
        case 0:
            return month
        case 1:
            guard let end = interval(of: month)?.end else { return nil }
            return self.month(containing: end)
        case -1:
            guard let start = start(of: month),
                let dayBefore = calendar.date(byAdding: .day, value: -1, to: start)
            else { return nil }
            return self.month(containing: dayBefore)
        default:
            guard let start = start(of: month),
                let date = calendar.date(byAdding: .month, value: offset, to: start)
            else { return nil }
            return self.month(containing: date)
        }
    }

    /// Lists months in a positive year within the era containing the reference date.
    public func months(in year: Int, relativeTo reference: Date) -> [MonthIdentifier] {
        guard year > 0 else { return [] }
        let era = calendar.component(.era, from: reference)
        guard
            let seed = calendar.date(from: DateComponents(era: era, year: year, month: 1, day: 1)),
            let yearInterval = calendar.dateInterval(of: .year, for: seed)
        else { return [] }
        var result: [MonthIdentifier] = []
        var cursor = yearInterval.start
        while cursor < yearInterval.end {
            guard let interval = calendar.dateInterval(of: .month, for: cursor),
                interval.end > cursor,
                let lastDay = calendar.date(byAdding: .day, value: -1, to: interval.end)
            else {
                break
            }
            for identifier in [month(containing: interval.start), month(containing: lastDay)]
            where identifier.era == era && identifier.year == year && result.last != identifier {
                result.append(identifier)
            }
            cursor = interval.end
        }
        return result
    }

    /// Returns the first day of the date's month that lies in the date's era.
    private func segmentStart(for date: Date) -> Date? {
        guard let monthStart = calendar.dateInterval(of: .month, for: date)?.start else {
            return nil
        }
        let era = calendar.component(.era, from: date)
        var day = monthStart
        while calendar.component(.era, from: day) != era {
            guard let next = calendar.date(byAdding: .day, value: 1, to: day), next <= date else {
                return monthStart
            }
            day = next
        }
        return day
    }
}
