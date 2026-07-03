import Foundation
import Testing

@testable import SwiftCommons

@Suite("Date+Extensions")
struct DateExtensionsTests {
    @Test
    func relativeDescriptionForPastDate() {
        let reference = Date(timeIntervalSince1970: 10_000)
        let anHourEarlier = reference.addingTimeInterval(-3600)
        let description = anHourEarlier.relativeDescription(
            to: reference, locale: Locale(identifier: "en_US"))
        #expect(description == "1 hour ago")
    }

    @Test
    func relativeDescriptionForFutureDate() {
        let reference = Date(timeIntervalSince1970: 10_000)
        let anHourLater = reference.addingTimeInterval(3600)
        let description = anHourLater.relativeDescription(
            to: reference, locale: Locale(identifier: "en_US"))
        #expect(description == "in 1 hour")
    }

    @Test
    func relativeDescriptionRespectsUnitsStyle() {
        let reference = Date(timeIntervalSince1970: 10_000)
        let anHourEarlier = reference.addingTimeInterval(-3600)
        let description = anHourEarlier.relativeDescription(
            to: reference, unitsStyle: .abbreviated, locale: Locale(identifier: "en_US"))
        #expect(description == "1h ago")
    }
}
