// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftlyFetch",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
    ],
    products: [
        .library(
            name: "SwiftlyFetch",
            targets: ["SwiftlyFetch"]
        ),
    ],
    targets: [
        .target(
            name: "SwiftlyFetch"
        ),
        .testTarget(
            name: "SwiftlyFetchTests",
            dependencies: ["SwiftlyFetch"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
