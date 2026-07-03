// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SwiftCommons",
    platforms: [.macOS(.v14), .iOS(.v17), .macCatalyst(.v17)],
    products: [
        .library(
            name: "SwiftCommons",
            targets: ["SwiftCommons"])
    ],
    traits: [
        .trait(
            name: "CSV", description: "Enables lightweight CSV parsing and serialization helpers")
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.1.0")
    ],
    targets: [
        .target(
            name: "SwiftCommons"),
        .testTarget(
            name: "SwiftCommonsTests",
            dependencies: ["SwiftCommons"],
            plugins: [
                .plugin(name: "SwiftFormatLintPlugin")
            ]),
        .plugin(
            name: "SwiftFormatLintPlugin",
            capability: .buildTool()),
    ],
    swiftLanguageModes: [.v6]
)
