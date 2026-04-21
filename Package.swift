// swift-tools-version: 6.1
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
            name: "RAGCore",
            targets: ["RAGCore"]
        ),
        .library(
            name: "RAGKit",
            targets: ["RAGKit"]
        ),
    ],
    targets: [
        .target(
            name: "RAGCore"
        ),
        .target(
            name: "RAGKit",
            dependencies: ["RAGCore"]
        ),
        .testTarget(
            name: "RAGCoreTests",
            dependencies: ["RAGCore"]
        ),
        .testTarget(
            name: "RAGKitTests",
            dependencies: ["RAGKit", "RAGCore"]
        ),
        .testTarget(
            name: "RAGKitIntegrationTests",
            dependencies: ["RAGKit", "RAGCore"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
