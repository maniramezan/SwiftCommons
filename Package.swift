// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SwiftCommons",
    platforms: [.macOS(.v13), .iOS(.v16), .macCatalyst(.v16)],
    products: [
        .library(
            name: "SwiftCommons",
            targets: ["SwiftCommons"])
    ],
    targets: [
        .target(
            name: "SwiftCommons",
            plugins: [
                .plugin(name: "SwiftFormatLintPlugin")
            ]),
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
