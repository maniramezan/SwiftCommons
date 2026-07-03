import Foundation

extension Bundle {

    /// The app's marketing version (`CFBundleShortVersionString`), e.g. `"2.3.1"`.
    ///
    /// `nil` if the bundle has no `Info.plist` or the key is missing, which is
    /// typical for non-app bundles (e.g. test bundles, SPM resource bundles).
    public var appVersion: String? {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }

    /// The app's build number (`CFBundleVersion`), e.g. `"142"`.
    ///
    /// `nil` if the bundle has no `Info.plist` or the key is missing.
    public var buildNumber: String? {
        object(forInfoDictionaryKey: "CFBundleVersion") as? String
    }

    /// A combined, user-presentable version string, e.g. `"2.3.1 (142)"`.
    ///
    /// Falls back gracefully if either component is unavailable:
    /// - Only ``appVersion`` known: `"2.3.1"`
    /// - Only ``buildNumber`` known: `"142"`
    /// - Neither known: `nil`
    public var versionAndBuildNumber: String? {
        switch (appVersion, buildNumber) {
        case (let version?, let build?): "\(version) (\(build))"
        case (let version?, nil): version
        case (nil, let build?): build
        case (nil, nil): nil
        }
    }
}
