// swift-tools-version: 6.0
import PackageDescription

let languageMode: SwiftSetting
#if os(Linux)
    languageMode = .swiftLanguageMode(.v6)
#else
    languageMode = .swiftLanguageVersion(.v6)
#endif

let package = Package(
    name: "swift-bitcoin",
    platforms: [.macOS(.v14), .iOS(.v17), .macCatalyst(.v17), .tvOS(.v17), .watchOS(.v10)],
    products: [
        .library(
            name: "Bitcoin",
            targets: ["Bitcoin"]),
        .executable(name: "bcnode", targets: ["BitcoinNode"]),
        .executable(name: "bcutil", targets: ["BitcoinUtility"])
    ],
    dependencies: [
        .package(url: "https://github.com/swift-bitcoin/secp256k1", from: "0.0.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-testing.git", from: "0.0.0"),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0"),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-nio-extras.git", from: "1.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "BitcoinNode", dependencies: [
                "Bitcoin",
                "BitcoinCrypto",
                "JSONRPC",
                .product(name: "Logging", package: "swift-log"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOExtras", package: "swift-nio-extras"),
                ],
            path: "src/bitcoin-node",
            swiftSettings: [languageMode]),
        .executableTarget(
            name: "BitcoinUtility", dependencies: [
                "Bitcoin",
                "JSONRPC",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "NIO", package: "swift-nio")],
            path: "src/bitcoin-utility",
            swiftSettings: [languageMode]),
        .target(
            name: "ECCHelper",
            dependencies: [.product(name: "LibSECP256k1", package: "secp256k1")],
            path: "src/ecc-helper"),
        .target(
            name: "BitcoinCrypto",
            dependencies: [
                "ECCHelper",
                .product(name: "Crypto", package: "swift-crypto", condition: .when(platforms: [.linux]))
            ],
            path: "src/bitcoin-crypto",
            swiftSettings: [languageMode]),
        .target(
            name: "Bitcoin",
            dependencies: [
                "BitcoinCrypto",
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms")],
            path: "src/bitcoin",
            swiftSettings: [languageMode]),
        .target(
            name: "JSONRPC",
            dependencies: [
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOFoundationCompat", package: "swift-nio")],
            path: "src/json-rpc",
            swiftSettings: [languageMode]),
        .testTarget(
            name: "BitcoinTests",
            dependencies: [
                "Bitcoin",
                .product(name: "Testing", package: "swift-testing", condition: .when(platforms: [.linux]))],
            path: "test/bitcoin",
            resources: [
                .copy("data")
            ],
            swiftSettings: [languageMode])
    ]
)
