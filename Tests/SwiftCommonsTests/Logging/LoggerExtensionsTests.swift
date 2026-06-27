import Foundation
import OSLog
import Testing

@testable import SwiftCommons

/// `Logger` exposes no public accessor for its subsystem/category, so these
/// tests exercise every helper for execution coverage and to guard against
/// crashes or malformed string interpolation in the logging paths.
@Suite("Logger extensions")
struct LoggerExtensionsTests {
    private struct SampleType {}

    enum SampleError: Error {
        case boom
    }

    @Test
    func swiftCommonsSubsystemConstant() {
        #expect(Logger.swiftCommonsSubsystem == "SwiftCommons")
    }

    @Test
    func factoryMethodsReturnLoggers() {
        // Smoke-test the factories; each must produce a usable Logger.
        let byCategory = Logger.swiftCommonsLogger(category: "Tests")
        let byType = Logger.swiftCommonsLogger(for: SampleType.self)
        let forType = Logger.forType(subsystem: "SwiftCommons", SampleType.self)
        let forCaller = Logger.forCaller(subsystem: "SwiftCommons")

        byCategory.infoPublic("category factory")
        byType.infoPublic("type factory")
        forType.infoPublic("forType factory")
        forCaller.infoPublic("forCaller factory")
    }

    @Test
    func privacyHelpersDoNotCrash() {
        let logger = Logger.swiftCommonsLogger(category: "Privacy")
        logger.debugPublic("debug public")
        logger.debugPrivate("debug private")
        logger.infoPublic("info public")
        logger.infoPrivate("info private")
        logger.errorPublic("error public")
        logger.errorPrivate("error private")
    }

    @Test
    func errorWithContextHelpers() {
        let logger = Logger.swiftCommonsLogger(category: "Errors")
        logger.error("Failed with context", error: SampleError.boom, context: "id=42")
        logger.error("Failed without context", error: SampleError.boom)
    }

    @Test
    func traceHelpers() {
        let logger = Logger.swiftCommonsLogger(category: "Trace")
        logger.traceEntry()
        logger.traceEntry("with message")
        logger.traceExit()
        logger.traceExit("with message")
    }
}
