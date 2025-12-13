// swift-tools-version: 6.1
import PackageDescription

// MLX is Apple Silicon only - exclude on Linux
#if os(Linux)
    let anyLanguageModelTraits: Set<Package.Dependency.Trait> = []
#else
    let anyLanguageModelTraits: Set<Package.Dependency.Trait> = ["MLX"]
#endif

// Noora uses Observation which has linker issues on Linux
#if os(Linux)
    let platformDependencies: [Package.Dependency] = []
    let platformTargetDependencies: [Target.Dependency] = []
#else
    let platformDependencies: [Package.Dependency] = [
        .package(url: "https://github.com/tuist/Noora", from: "0.15.0"),
    ]
    let platformTargetDependencies: [Target.Dependency] = [
        .product(name: "Noora", package: "Noora"),
    ]
#endif

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
        .package(url: "https://github.com/stephencelis/SQLite.swift", from: "0.15.3"),
        .package(url: "https://github.com/apple/swift-crypto", from: "4.2.0"),
        .package(
            url: "https://github.com/mattt/AnyLanguageModel",
            branch: "main",
            traits: anyLanguageModelTraits
        ),
        .package(url: "https://github.com/jpsim/Yams", from: "5.1.3"),
    ] + platformDependencies,
    targets: [
        .executableTarget(
            name: "clai",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "SQLite", package: "SQLite.swift"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "AnyLanguageModel", package: "AnyLanguageModel"),
                .product(name: "Yams", package: "Yams"),
            ] + platformTargetDependencies,
            path: "Sources/clai"
        ),
        .testTarget(
            name: "claiTests",
            dependencies: ["clai"],
            path: "Tests/claiTests"
        ),
    ]
)
