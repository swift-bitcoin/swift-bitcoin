// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "swift-bitcoin",
    platforms: [.macOS(.v14), .iOS(.v17), .macCatalyst(.v17), .tvOS(.v17), .watchOS(.v10)],
    products: [
        .library(
            name: "Bitcoin",
            targets: ["Bitcoin"]),
        .executable(name: "bcnode", targets: ["bcnode"]),
        .executable(name: "bcutil", targets: ["bcutil"])
    ],
    dependencies: [
        .package(url: "https://github.com/attaswift/BigInt.git", from: "5.3.0"),
        .package(url: "https://github.com/swift-bitcoin/secp256k1", from: "0.4.0"),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.3.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.3"),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "2.0.0-alpha.1"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.62.0")
    ],
    targets: [
        .executableTarget(
            name: "bcnode", dependencies: [
                "Bitcoin",
                "BitcoinP2P",
                "JSONRPC",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
                .product(name: "NIO", package: "swift-nio")],
            path: "src/bitcoin-node"),
        .executableTarget(
            name: "bcutil", dependencies: [
                "Bitcoin",
                "JSONRPC",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "NIO", package: "swift-nio")],
            path: "src/bitcoin-utility"),
        .target(
            name: "ECCHelper",
            dependencies: [.product(name: "LibSECP256k1", package: "secp256k1")],
            path: "src/ecc-helper"),
        .target(
            name: "BitcoinCrypto",
            dependencies: [
                "ECCHelper",
                "BigInt",
                .product(name: "Crypto", package: "swift-crypto", condition: .when(platforms: [.linux]))
            ],
            path: "src/bitcoin-crypto"),
        .target(
            name: "Bitcoin",
            dependencies: [
                "BitcoinCrypto",
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms")],
            path: "src/bitcoin"),
        .target(
            name: "BitcoinP2P",
            dependencies: [
                "Bitcoin",
                "BitcoinCrypto",
                "JSONRPC",
                .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms")],
            path: "src/bitcoin-p2p"),
        .target(
            name: "JSONRPC",
            dependencies: [
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOFoundationCompat", package: "swift-nio")],
            path: "src/json-rpc"),
        .testTarget(
            name: "BitcoinTests",
            dependencies: ["Bitcoin"],
            path: "test/bitcoin",
            resources: [
                .copy("data")
            ])
    ]
)
