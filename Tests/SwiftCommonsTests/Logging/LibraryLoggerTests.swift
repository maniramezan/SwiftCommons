import Foundation
import Testing
import os

@testable import SwiftCommons

@Suite("LibraryLogger")
struct LibraryLoggerTests {
    private struct SampleError: Error {}

    @Test
    func levelDefaultsToWarning() {
        let logger = LibraryLogger(subsystem: "LibraryLoggerTests")
        #expect(logger.level == .warning)
    }

    @Test
    func defaultLevelCanBeOverridden() {
        let logger = LibraryLogger(subsystem: "LibraryLoggerTests", defaultLevel: .debug)
        #expect(logger.level == .debug)
    }

    @Test
    func levelsAreOrderedFromLeastToMostVerbose() {
        #expect(LibraryLogger.Level.allCases.sorted() == [.off, .error, .warning, .info, .debug])
    }

    @Test(arguments: LibraryLogger.Level.allCases)
    func isEnabledIncludesTheLevelAndEveryMoreSevereOne(threshold: LibraryLogger.Level) {
        let logger = LibraryLogger(subsystem: "LibraryLoggerTests", defaultLevel: threshold)
        let enabled = LibraryLogger.Level.allCases.filter(logger.isEnabled)
        let expected = LibraryLogger.Level.allCases.filter { $0 != .off && $0 <= threshold }
        #expect(enabled == expected)
    }

    @Test
    func offIsNeverEnabled() {
        let logger = LibraryLogger(subsystem: "LibraryLoggerTests", defaultLevel: .debug)
        #expect(!logger.isEnabled(.off))
    }

    @Test
    func categoryEmitsOnlyMessagesAtOrAboveTheLevel() {
        let recorder = EmissionRecorder()
        let logger = LibraryLogger(
            subsystem: "LibraryLoggerTests", defaultLevel: .warning,
            emissionObserver: recorder.record)
        let category = logger.category("network")

        logAtEveryLevel(category)

        #expect(
            recorder.emissions == [
                Emission(level: .warning, category: "network"),
                Emission(level: .error, category: "network"),
                Emission(level: .error, category: "network"),
            ])
    }

    @Test
    func setLevelAppliesToExistingCategories() {
        let recorder = EmissionRecorder()
        let logger = LibraryLogger(
            subsystem: "LibraryLoggerTests", defaultLevel: .off,
            emissionObserver: recorder.record)
        let category = logger.category("cache")

        logAtEveryLevel(category)
        #expect(recorder.emissions.isEmpty)

        logger.setLevel(.debug)
        logAtEveryLevel(category)
        #expect(
            recorder.emissions.map(\.level) == [.debug, .debug, .info, .warning, .error, .error])
    }

    @Test
    func skippedMessagesAreNeverBuilt() {
        let logger = LibraryLogger(subsystem: "LibraryLoggerTests", defaultLevel: .error)
        let category = logger.category("network")
        let builds = OSAllocatedUnfairLock(initialState: 0)
        let message: @Sendable () -> String = {
            builds.withLock { $0 += 1 }
            return "message"
        }

        category.debug(message())
        category.info(message())
        category.warning(message())
        #expect(builds.withLock { $0 } == 0)

        category.error(message())
        #expect(builds.withLock { $0 } == 1)
    }

    @Test
    func loggersHaveIndependentLevels() {
        let first = LibraryLogger(subsystem: "FirstLibrary")
        let second = LibraryLogger(subsystem: "SecondLibrary")

        first.setLevel(.debug)

        #expect(first.level == .debug)
        #expect(second.level == .warning)
    }

    @Test
    func setLevelIsSafeUnderConcurrentReadsAndWrites() async {
        let logger = LibraryLogger(subsystem: "LibraryLoggerTests")
        let category = logger.category("concurrency")

        await withTaskGroup(of: Void.self) { group in
            for index in 0..<500 {
                group.addTask {
                    logger.setLevel(LibraryLogger.Level.allCases[index % 5])
                    _ = logger.isEnabled(.info)
                    category.debug("iteration \(index)")
                }
            }
        }
        logger.setLevel(.info)

        #expect(logger.level == .info)
    }

    @Test
    func categoryKeepsItsName() {
        let logger = LibraryLogger(subsystem: "LibraryLoggerTests")
        #expect(logger.category("auth").name == "auth")
        #expect(logger.subsystem == "LibraryLoggerTests")
    }

    private func logAtEveryLevel(_ category: LibraryLogger.Category) {
        category.debug("debug")
        category.debug("debug url", url: "https://example.com/path?token=secret")
        category.info("info")
        category.warning("warning")
        category.error("error")
        category.error("error with underlying", error: SampleError())
    }

    private struct Emission: Equatable {
        let level: LibraryLogger.Level
        let category: String
    }

    private final class EmissionRecorder: Sendable {
        private let storage = OSAllocatedUnfairLock<[Emission]>(initialState: [])

        var emissions: [Emission] {
            storage.withLock { $0 }
        }

        @Sendable
        func record(level: LibraryLogger.Level, category: String) {
            storage.withLock { $0.append(Emission(level: level, category: category)) }
        }
    }
}
