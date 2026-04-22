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
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.7.3"),
    ],
    targets: [
        .target(
            name: "RAGCore"
        ),
        .target(
            name: "RAGKit",
            dependencies: [
                "RAGCore",
                .product(name: "Markdown", package: "swift-markdown"),
            ]
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
