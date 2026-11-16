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
        (-1, "-0:01"),
        (-61, "-1:01"),
        (-3601, "-1:00:01"),
        (Int.min, "-2562047788015215:30:08"),
    ])
    func formatsNegativeValues(seconds: Int, expected: String) {
        #expect(DurationFormatter.format(seconds: seconds) == expected)
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

    @Test(arguments: [
        (Duration.zero, "0:00"),
        (.seconds(5), "0:05"),
        (.seconds(225), "3:45"),
        (.milliseconds(3_750_000), "1:02:30"),
        (.seconds(3600), "1:00:00"),
        (.seconds(-61), "-1:01"),
    ])
    func formatsDurations(duration: Duration, expected: String) {
        #expect(DurationFormatter.format(duration) == expected)
    }

    @Test
    func truncatesFractionalSecondsTowardZero() {
        #expect(DurationFormatter.format(.milliseconds(1_999)) == "0:01")
        #expect(DurationFormatter.format(.milliseconds(-1_999)) == "-0:01")
        #expect(DurationFormatter.format(.milliseconds(999)) == "0:00")
    }
}
