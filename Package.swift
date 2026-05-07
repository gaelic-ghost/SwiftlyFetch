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
            name: "FetchCore",
            targets: ["FetchCore"]
        ),
        .library(
            name: "FetchKit",
            targets: ["FetchKit"]
        ),
        .library(
            name: "RAGKit",
            targets: ["RAGKit"]
        ),
        .library(
            name: "SwiftlyFetch",
            targets: ["SwiftlyFetch"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.7.3"),
    ],
    targets: [
        .target(
            name: "RAGCore"
        ),
        .target(
            name: "FetchCore"
        ),
        .target(
            name: "FetchKit",
            dependencies: ["FetchCore"]
        ),
        .target(
            name: "RAGKit",
            dependencies: [
                "RAGCore",
                .product(name: "Markdown", package: "swift-markdown"),
            ]
        ),
        .target(
            name: "SwiftlyFetch",
            dependencies: [
                "FetchCore",
                "FetchKit",
                "RAGCore",
                "RAGKit",
            ]
        ),
        .target(
            name: "SwiftlyFetchTestFixtures",
            dependencies: ["FetchCore"],
            path: "Tests/SwiftlyFetchTestFixtures"
        ),
        .testTarget(
            name: "RAGCoreTests",
            dependencies: ["RAGCore"]
        ),
        .testTarget(
            name: "FetchCoreTests",
            dependencies: ["FetchCore"]
        ),
        .testTarget(
            name: "FetchKitTests",
            dependencies: ["FetchKit", "FetchCore", "SwiftlyFetchTestFixtures"]
        ),
        .testTarget(
            name: "RAGKitTests",
            dependencies: ["RAGKit", "RAGCore"]
        ),
        .testTarget(
            name: "RAGKitIntegrationTests",
            dependencies: ["RAGKit", "RAGCore"]
        ),
        .testTarget(
            name: "SwiftlyFetchTests",
            dependencies: ["SwiftlyFetch", "FetchCore", "RAGCore", "RAGKit", "SwiftlyFetchTestFixtures"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
