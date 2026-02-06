// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SwiftCommons",
    platforms: [.macOS(.v11), .iOS(.v16), .macCatalyst(.v16)],
    products: [
        .library(
            name: "SwiftCommons",
            targets: ["SwiftCommons"])
    ],
    targets: [
        .target(name: "SwiftCommons"),
        .testTarget(
            name: "SwiftCommonsTests",
            dependencies: ["SwiftCommons"]),
    ],
    swiftLanguageModes: [.v6]
)
