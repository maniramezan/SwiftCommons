import Testing

@testable import SwiftCommons

@Suite("DurationFormatter")
struct DurationFormatterTests {
    @Test
    func formatsZero() {
        #expect(DurationFormatter.format(seconds: 0) == "0:00")
    }

    @Test
    func formatsSecondsOnly() {
        #expect(DurationFormatter.format(seconds: 5) == "0:05")
    }

    @Test
    func padsSecondsToTwoDigits() {
        #expect(DurationFormatter.format(seconds: 65) == "1:05")
    }

    @Test
    func formatsMinutesAndSeconds() {
        #expect(DurationFormatter.format(seconds: 225) == "3:45")
    }

    @Test
    func formatsHoursMinutesSeconds() {
        #expect(DurationFormatter.format(seconds: 3750) == "1:02:30")
    }

    @Test
    func formatsExactlyOneHour() {
        #expect(DurationFormatter.format(seconds: 3600) == "1:00:00")
    }

    @Test(arguments: [
        (0, "0:00"),
        (59, "0:59"),
        (60, "1:00"),
        (3599, "59:59"),
        (3661, "1:01:01"),
    ])
    func formatsKnownValues(seconds: Int, expected: String) {
        #expect(DurationFormatter.format(seconds: seconds) == expected)
    }
}
