import Foundation
import Testing

@testable import SwiftCommons

@Suite("ConfigValue")
struct ConfigValueTests {
    @Test
    func boolCoercion() {
        #expect(ConfigValue.bool(true).boolValue)
        #expect(ConfigValue.string("true").boolValue)
        #expect(ConfigValue.string("TRUE").boolValue)
        #expect(ConfigValue.string("1").boolValue)
        #expect(!ConfigValue.string("false").boolValue)
        #expect(!ConfigValue.string("anything").boolValue)
        #expect(ConfigValue.int(2).boolValue)
        #expect(!ConfigValue.int(0).boolValue)
        #expect(ConfigValue.double(0.5).boolValue)
        #expect(!ConfigValue.double(0).boolValue)
    }

    @Test
    func stringCoercion() {
        #expect(ConfigValue.string("hi").stringValue == "hi")
        #expect(ConfigValue.bool(true).stringValue == "true")
        #expect(ConfigValue.int(7).stringValue == "7")
        #expect(ConfigValue.double(1.5).stringValue == "1.5")
    }

    @Test
    func intCoercion() {
        #expect(ConfigValue.int(7).intValue == 7)
        #expect(ConfigValue.string("42").intValue == 42)
        #expect(ConfigValue.string("nope").intValue == 0)
        #expect(ConfigValue.double(3.9).intValue == 3)
        #expect(ConfigValue.bool(true).intValue == 1)
        #expect(ConfigValue.bool(false).intValue == 0)
    }

    @Test
    func doubleCoercion() {
        #expect(ConfigValue.double(2.5).doubleValue == 2.5)
        #expect(ConfigValue.string("3.25").doubleValue == 3.25)
        #expect(ConfigValue.string("nope").doubleValue == 0.0)
        #expect(ConfigValue.int(4).doubleValue == 4.0)
        #expect(ConfigValue.bool(true).doubleValue == 1.0)
    }

    @Test
    func isHashable() {
        let set: Set<ConfigValue> = [.int(1), .int(1), .string("1")]
        #expect(set.count == 2)
    }

    @Test
    func environmentWrapsEveryValueAsString() {
        let config = ConfigValue.environment(["DEBUG_MODE": "true", "RETRY_COUNT": "3"])
        #expect(config["DEBUG_MODE"] == .string("true"))
        #expect(config["RETRY_COUNT"] == .string("3"))
        #expect(config["DEBUG_MODE"]?.boolValue == true)
        #expect(config["RETRY_COUNT"]?.intValue == 3)
    }

    @Test
    func environmentDefaultsToProcessInfoEnvironment() {
        let config = ConfigValue.environment()
        #expect(config.count == ProcessInfo.processInfo.environment.count)
    }
}
