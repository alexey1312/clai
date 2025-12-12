// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "clai",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "clai", targets: ["clai"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
        .package(url: "https://github.com/tuist/Noora", from: "0.15.0"),
        .package(url: "https://github.com/stephencelis/SQLite.swift", from: "0.15.3"),
        .package(
            url: "https://github.com/mattt/AnyLanguageModel",
            branch: "main",
            traits: ["MLX"]
        ),
        .package(url: "https://github.com/jpsim/Yams", from: "5.1.3"),
    ],
    targets: [
        .executableTarget(
            name: "clai",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Noora", package: "Noora"),
                .product(name: "SQLite", package: "SQLite.swift"),
                .product(name: "AnyLanguageModel", package: "AnyLanguageModel"),
                .product(name: "Yams", package: "Yams"),
            ],
            path: "Sources/clai"
        ),
        .testTarget(
            name: "claiTests",
            dependencies: ["clai"],
            path: "Tests/claiTests"
        ),
    ]
)
