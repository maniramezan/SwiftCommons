import Foundation

public extension Calendar {
    /// Errors thrown by calendar date computations.
    enum CalendarError: Error {
        /// Unable to compute the start of a week.
        case cannotCalculateStartOfWeek
        /// Unable to compute the start of a month.
        case cannotCalculateStartOfMonth
        /// Unable to compute the number of days in a month.
        case cannotCalculateNumberOfDays
        /// Unable to compute the first date of the next month.
        case cannotCalculateNextMonthFirstDate
        /// Unable to compute the first date of the previous month.
        case cannotCalculatePreviousMonthFirstDate
        /// Unable to compute a date from the given components.
        case cannotCalculateDate
    }

    /// Month name presentation style.
    enum NameType {
        /// Very short month symbols (e.g., "J").
        case veryShort
        /// Short month symbols (e.g., "Jan").
        case short
        /// Standalone month symbols (e.g., "January").
        case standalone
        /// Very short standalone month symbols.
        case veryShortStandalone
    }

    /// Returns the first day of the week containing the given date.
    func startOfWeek(of date: Date) throws -> Date {
        guard let startOfWeekDate = self.date(
            from: self.dateComponents([.yearForWeekOfYear, .weekOfYear],
                                          from: date))
        else {
            throw CalendarError.cannotCalculateStartOfWeek
        }
        return startOfWeekDate
    }

    /// Returns the first day of the month containing the given date.
    func startOfMonth(for date: Date) throws -> Date {
        guard let startOfMonthDate = self.date(from: dateComponents(
            [.year, .month],
            from: date))
        else {
            throw CalendarError.cannotCalculateStartOfMonth
        }

        return startOfMonthDate
    }

    /// Returns the weekday index of the first day of the month containing the date.
    func startOfMonthDay(for date: Date) throws -> Int {
        let startOfMonthDate = try startOfMonth(for: date)
        return self.component(.weekday, from: startOfMonthDate)
    }

    /// Returns the number of days in a month for the given year.
    func numberOfDays(in month: Int, year: Int) throws -> Int {
        let dateComponents = DateComponents(year: year, month: month)
        guard let date = self.date(from: dateComponents),
              let range = self.range(of: .day, in: .month, for: date)
        else {
            throw CalendarError.cannotCalculateNumberOfDays
        }
        return range.count
    }

    /// Returns the number of days in the month containing the given date.
    func numberOfDays(for date: Date) throws -> Int {
        let year = year(from: date)
        let month = month(from: date)
        let dateComponents = DateComponents(year: year, month: month)
        guard let date = self.date(from: dateComponents),
              let range = self.range(of: .day, in: .month, for: date)
        else {
            throw CalendarError.cannotCalculateNumberOfDays
        }
        return range.count
    }

    /// Returns a month symbol for the date using the specified name type.
    func monthSymbol(for date: Date, type: NameType = .standalone) -> String {
        let month = month(from: date)
        let nameSymbols: [String]
        switch type {
        case .veryShort:
            nameSymbols =  veryShortMonthSymbols
        case .short:
            nameSymbols = shortMonthSymbols
        case .standalone:
            nameSymbols = standaloneMonthSymbols
        case .veryShortStandalone:
            nameSymbols = veryShortStandaloneMonthSymbols
        }
        return nameSymbols[month - 1]
    }

    /// Returns the month component of the date.
    func month(from date: Date) -> Int {
        component(.month, from: date)
    }

    /// Returns the year component of the date.
    func year(from date: Date) -> Int {
        component(.year, from: date)
    }

    /// Returns the day component of the date.
    func day(from date: Date) -> Int {
        component(.day, from: date)
    }

    /// Returns the first date of the next month.
    func nextMonthFirstDate(for date: Date) throws -> Date {
        let month = month(from: date)
        let year = year(from: date)
        let nextMonth = month + 1
        let nextYear = nextMonth > 12 ? year + 1 : year
        let nextMonthNumber = nextMonth > 12 ? 1 : nextMonth
        guard let firstDayDate = self.date(from: DateComponents(
            year: nextYear,
            month: nextMonthNumber,
            day: 1))
        else {
            throw CalendarError.cannotCalculateNextMonthFirstDate
        }
        return firstDayDate
    }

    /// Returns the first date of the previous month.
    func previousMonthFirstDate(for date: Date) throws -> Date {
        let month = month(from: date)
        let year = year(from: date)
        let previousMonth = month - 1
        let previousYear = previousMonth < 1 ? year - 1 : year
        let previousMonthNumber = previousMonth < 1 ? 12 : previousMonth
        guard let firstDayDate = self.date(from: DateComponents(
            year: previousYear,
            month: previousMonthNumber,
            day: 1))
        else {
            throw CalendarError.cannotCalculatePreviousMonthFirstDate
        }
        return firstDayDate
    }

    /// Returns the same day in the next year.
    func nextYear(for date: Date) throws -> Date {
        try sameDay(date, byAddingYears: 1)
    }

    /// Returns the same day in the previous year.
    func previousYear(for date: Date) throws -> Date {
        try sameDay(date, byAddingYears: -1)
    }

    /// Returns the date updated to the specified year, preserving month/day when possible.
    func updateYear(_ year: Int, for date: Date) throws -> Date {
        try sameDay(date, byAddingYears: year - self.year(from: date))
    }

    /// Returns the date updated to the specified month, preserving day when possible.
    func updateMonth(_ month: Int, for date: Date) throws -> Date {
        try sameDay(date, byAddingMonths: month - self.month(from: date))
    }

    /// Returns the date by adding years while keeping the same day when possible.
    func sameDay(_ date: Date, byAddingYears years: Int) throws -> Date {
        let dateComponents = DateComponents(year: years)

        guard let newDate = self.date(byAdding: dateComponents, to: date)
        else {
            throw CalendarError.cannotCalculateDate
        }
        
        return newDate
    }

    /// Returns the date by adding months while keeping the same day when possible.
    func sameDay(_ date: Date, byAddingMonths months: Int) throws -> Date {

        let dateComponents = DateComponents(month: months)
        guard let newDate = self.date(byAdding: dateComponents, to: date)
        else {
            throw CalendarError.cannotCalculateDate
        }
        return newDate
    }

    /// Returns true when the provided day/month/year match today in this calendar.
    func isToday(day: Int, month: Int, year: Int) -> Bool {
        let today = Date()
        let todayYear = self.year(from: today)
        let todayMonth = self.month(from: today)
        let todayDay = self.day(from: today)
        return todayDay == day && todayMonth == month && todayYear == year
    }
}
