// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "swift-bitcoin",
    platforms: [.macOS(.v14), .iOS(.v17), .macCatalyst(.v17), .tvOS(.v17), .watchOS(.v10), .visionOS(.v1)],
    products: [
        .library(name: "Bitcoin", targets: ["Bitcoin"]),
        .library(name: "BitcoinTransport", targets: ["BitcoinTransport"]),
        .library(name: "BitcoinBlockchain", targets: ["BitcoinBlockchain"]),
        .library(name: "BitcoinWallet", targets: ["BitcoinWallet"]),
        .library(name: "BitcoinBase", targets: ["BitcoinBase"]),
        .library(name: "BitcoinCrypto", targets: ["BitcoinCrypto"]),
        .executable(name: "bcnode", targets: ["BitcoinNode"]),
        .executable(name: "bcutil", targets: ["BitcoinUtility"])
    ],
    dependencies: [
        .package(url: "https://github.com/swift-bitcoin/secp256k1", from: "0.0.0"),
        .package(url: "https://github.com/apple/swift-testing.git", from: "0.0.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-nio-extras.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "Bitcoin",
            dependencies: [
                "BitcoinTransport",
                "BitcoinBlockchain",
                "BitcoinWallet",
                "BitcoinBase",
                "BitcoinCrypto"],
            path: "src/bitcoin",
            swiftSettings: [.swiftLanguageMode(.v6)]),
        .target(
            name: "BitcoinTransport",
            dependencies: [
                "BitcoinBlockchain",
                "BitcoinBase",
                "BitcoinCrypto",
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms")],
            path: "src/bitcoin-transport",
            swiftSettings: [.swiftLanguageMode(.v6)]),
        .target(
            name: "BitcoinBlockchain",
            dependencies: [
                "BitcoinBase",
                "BitcoinCrypto",
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms")],
            path: "src/bitcoin-blockchain",
            swiftSettings: [.swiftLanguageMode(.v6)]),
        .target(
            name: "BitcoinWallet",
            dependencies: [
                "BitcoinBase",
                "BitcoinCrypto"],
            path: "src/bitcoin-wallet",
            swiftSettings: [.swiftLanguageMode(.v6)]),
        .target(
            name: "BitcoinBase",
            dependencies: ["BitcoinCrypto"],
            path: "src/bitcoin-base",
            swiftSettings: [.swiftLanguageMode(.v6)]),
        .target(
            name: "BitcoinCrypto",
            dependencies: [
                "ECCHelper",
                .product(name: "Crypto", package: "swift-crypto", condition: .when(platforms: [.linux]))
            ],
            path: "src/bitcoin-crypto",
            swiftSettings: [.swiftLanguageMode(.v6)]),
        .target(
            name: "ECCHelper",
            dependencies: [.product(name: "LibSECP256k1", package: "secp256k1")],
            path: "src/ecc-helper"),
        .target(
            name: "BitcoinRPC",
            dependencies: [
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOFoundationCompat", package: "swift-nio")],
            path: "src/bitcoin-rpc",
            swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(
            name: "BitcoinBaseTests",
            dependencies: [
                "BitcoinBase",
                .product(name: "Testing", package: "swift-testing", condition: .when(platforms: [.linux]))],
            path: "test/bitcoin-base",
            resources: [
                .copy("data")
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(
            name: "BitcoinCryptoTests",
            dependencies: [
                "BitcoinCrypto",
                .product(name: "Testing", package: "swift-testing", condition: .when(platforms: [.linux]))],
            path: "test/bitcoin-crypto",
            swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(
            name: "BitcoinWalletTests",
            dependencies: [
                "BitcoinWallet",
                .product(name: "Testing", package: "swift-testing", condition: .when(platforms: [.linux]))],
            path: "test/bitcoin-wallet",
            swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(
            name: "BitcoinTransportTests",
            dependencies: [
                "BitcoinTransport",
                .product(name: "Testing", package: "swift-testing", condition: .when(platforms: [.linux]))],
            path: "test/bitcoin-transport",
            swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(
            name: "BitcoinBlockchainTests",
            dependencies: [
                "BitcoinBlockchain",
                .product(name: "Testing", package: "swift-testing", condition: .when(platforms: [.linux]))],
            path: "test/bitcoin-blockchain",
            swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(
            name: "BitcoinTests",
            dependencies: [
                "Bitcoin",
                .product(name: "Testing", package: "swift-testing", condition: .when(platforms: [.linux]))],
            path: "test/bitcoin",
            swiftSettings: [.swiftLanguageMode(.v6)]),
        .executableTarget(
            name: "BitcoinNode", dependencies: [
                "BitcoinTransport",
                "BitcoinBlockchain",
                "BitcoinBase",
                "BitcoinCrypto",
                "BitcoinRPC",
                .product(name: "Logging", package: "swift-log"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOExtras", package: "swift-nio-extras"),
                ],
            path: "src/bitcoin-node",
            swiftSettings: [.swiftLanguageMode(.v6)]),
        .executableTarget(
            name: "BitcoinUtility", dependencies: [
                "BitcoinBlockchain",
                "BitcoinWallet",
                "BitcoinBase",
                "BitcoinCrypto",
                "BitcoinRPC",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "NIO", package: "swift-nio")],
            path: "src/bitcoin-utility",
            swiftSettings: [.swiftLanguageMode(.v6)])
    ]
)
