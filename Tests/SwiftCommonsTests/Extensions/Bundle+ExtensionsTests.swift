import Foundation
import Testing

@testable import SwiftCommons

@Suite("Bundle+Extensions")
struct BundleExtensionsTests {
    private func makeBundle(version: String?, build: String?) throws -> Bundle {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathExtension("bundle")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        var info: [String: Any] = [:]
        if let version {
            info["CFBundleShortVersionString"] = version
        }
        if let build {
            info["CFBundleVersion"] = build
        }

        let plistURL = root.appendingPathComponent("Info.plist")
        let data = try PropertyListSerialization.data(
            fromPropertyList: info, format: .xml, options: 0)
        try data.write(to: plistURL)

        return try #require(Bundle(url: root))
    }

    @Test
    func appVersionReadsShortVersionString() throws {
        let bundle = try makeBundle(version: "2.3.1", build: nil)
        #expect(bundle.appVersion == "2.3.1")
    }

    @Test
    func buildNumberReadsBundleVersion() throws {
        let bundle = try makeBundle(version: nil, build: "142")
        #expect(bundle.buildNumber == "142")
    }

    @Test
    func missingKeysReturnNil() throws {
        let bundle = try makeBundle(version: nil, build: nil)
        #expect(bundle.appVersion == nil)
        #expect(bundle.buildNumber == nil)
        #expect(bundle.versionAndBuildNumber == nil)
    }

    @Test
    func versionAndBuildNumberCombinesBothComponents() throws {
        let bundle = try makeBundle(version: "2.3.1", build: "142")
        #expect(bundle.versionAndBuildNumber == "2.3.1 (142)")
    }

    @Test
    func versionAndBuildNumberFallsBackToVersionOnly() throws {
        let bundle = try makeBundle(version: "2.3.1", build: nil)
        #expect(bundle.versionAndBuildNumber == "2.3.1")
    }

    @Test
    func versionAndBuildNumberFallsBackToBuildOnly() throws {
        let bundle = try makeBundle(version: nil, build: "142")
        #expect(bundle.versionAndBuildNumber == "142")
    }
}
