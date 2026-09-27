// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SwiftCommons",
    platforms: [.macOS(.v14), .iOS(.v17), .macCatalyst(.v17)],
    products: [
        .library(
            name: "SwiftCommons",
            targets: ["SwiftCommons"]),
        .library(
            name: "SwiftCommonsTestSupport",
            targets: ["SwiftCommonsTestSupport"]),
    ],
    traits: [
        .trait(
            name: "SwiftData",
            description:
                "Enables the SwiftData-backed APIs: ModelContainer helpers and the SyncEngine"),
        .trait(
            name: "CSV", description: "Enables lightweight CSV parsing and serialization helpers"),
        .default(enabledTraits: ["SwiftData"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.5.0")
    ],
    targets: [
        .target(
            name: "SwiftCommons"),
        .target(
            name: "SwiftCommonsTestSupport",
            dependencies: ["SwiftCommons"]),
        .testTarget(
            name: "SwiftCommonsTests",
            dependencies: ["SwiftCommons", "SwiftCommonsTestSupport"],
            plugins: [
                .plugin(name: "SwiftFormatLintPlugin")
            ]),
        .plugin(
            name: "SwiftFormatLintPlugin",
            capability: .buildTool()),
    ],
    swiftLanguageModes: [.v6]
)
