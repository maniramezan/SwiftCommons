import Foundation

extension CalendarArithmetic {
    /// Returns the month's dates padded to complete weeks, or `nil` for an invalid month.
    ///
    ///     let arithmetic = CalendarArithmetic(calendar: Calendar(identifier: .gregorian))
    ///     let dates = arithmetic.gridDates(in: MonthIdentifier(month: 2, year: 2028))
    ///
    /// Weeks begin on ``calendar``'s `firstWeekday`. Each date is the start of a
    /// calendar day, and neighboring dates are computed using calendar arithmetic
    /// so daylight-saving transitions do not shift their local day boundaries.
    ///
    /// Era-split months include only their own segment before padding. Leading
    /// and trailing dates may belong to another month, leap month, or era; compare
    /// each date's ``month(containing:)`` identity to identify padding.
    ///
    /// - Parameter month: The month identity to resolve with this calendar.
    /// - Returns: Consecutive day starts in complete seven-day rows, or `nil` if
    ///   the month or a required date cannot be resolved.
    public func gridDates(in month: MonthIdentifier) -> [Date]? {
        let daysPerWeek = 7
        guard let interval = interval(of: month) else { return nil }
        let leadingCount =
            (calendar.component(.weekday, from: interval.start) - calendar.firstWeekday
                + daysPerWeek)
            % daysPerWeek
        guard
            let gridStart = calendar.date(byAdding: .day, value: -leadingCount, to: interval.start)
        else {
            return nil
        }

        var dates: [Date] = []
        var day = calendar.startOfDay(for: gridStart)
        while day < interval.end || !dates.count.isMultiple(of: daysPerWeek) {
            dates.append(day)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { return nil }
            let nextDay = calendar.startOfDay(for: next)
            guard nextDay > day else { return nil }
            day = nextDay
        }
        return dates
    }
}
