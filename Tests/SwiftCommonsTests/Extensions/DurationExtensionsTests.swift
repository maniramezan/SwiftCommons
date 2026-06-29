import Foundation
import Testing

@testable import SwiftCommons

@Suite("Duration extensions")
struct DurationExtensionsTests {
    @Test(arguments: [
        (Duration.seconds(0), 0.0),
        (.seconds(2), 2.0),
        (.seconds(1.5), 1.5),
        (.milliseconds(250), 0.25),
        (.seconds(-1.25), -1.25),
    ])
    func timeInterval(duration: Duration, expected: TimeInterval) {
        #expect(duration.timeInterval == expected)
    }
}
