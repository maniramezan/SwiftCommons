import SwiftCommons
import Testing

@Suite("AppVersion")
struct AppVersionTests {
    @Test(arguments: [
        ("2", "2.0.0"),
        ("2.4", "2.4.0"),
        ("2.4.6", "2.4.6"),
        ("  2.4.6\n", "2.4.6"),
        ("002.04.006", "2.4.6"),
        ("2.4.6-preview.1", "2.4.6"),
        ("2.4.6+123", "2.4.6"),
        ("2.4-preview+123", "2.4.0"),
        ("0", "0.0.0"),
    ])
    func normalizesVersions(raw: String, normalized: String) throws {
        let version = try #require(AppVersion(string: raw))
        #expect(version.description == normalized)
        #expect(AppVersion(string: version.description) == version)
    }

    @Test(arguments: [
        "", " ", ".", "2.", ".2", "2..4", "2.4.6.8", "-2.4.6", "+2.4.6",
        "2.-4.6", "v2.4.6", "2.x.6", "2. 4.6", "２.４.６", "٢.٤.٦",
        "999999999999999999999999999999", "2.999999999999999999999999999999",
    ])
    func rejectsInvalidVersions(raw: String) {
        #expect(AppVersion(string: raw) == nil)
    }

    @Test func exposesComponents() throws {
        let version = try #require(AppVersion(string: "3.12.45"))
        #expect(version.major == 3)
        #expect(version.minor == 12)
        #expect(version.patch == 45)
    }

    @Test(arguments: [
        ("1.9.9", "2.0.0"),
        ("2.9.9", "2.10.0"),
        ("2.4.9", "2.4.10"),
        ("0.0.0", "0.0.1"),
    ])
    func comparesComponentsNumerically(older: String, newer: String) throws {
        let first = try #require(AppVersion(string: older))
        let second = try #require(AppVersion(string: newer))
        #expect(first < second)
        #expect(second > first)
    }

    @Test func equivalentVersionsHaveTheSameIdentity() throws {
        let versions = try ["2", "2.0", "2.0.0", "2.0.0-preview", "2.0.0+42"].map {
            try #require(AppVersion(string: $0))
        }
        #expect(Set(versions).count == 1)
    }
}
