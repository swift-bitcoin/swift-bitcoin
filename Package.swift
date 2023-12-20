// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "swift-bitcoin",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(
            name: "Bitcoin",
            targets: ["Bitcoin"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-bitcoin/secp256k1", from: "0.4.0"),
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.3.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.3"),
    ],
    targets: [
        .executableTarget(
            name: "bitcoin-cli", dependencies: [
                "Bitcoin",
                .product(name: "ArgumentParser", package: "swift-argument-parser")],
            path: "src/bitcoin-cli"),
        .target(
            name: "ECCHelper",
            dependencies: [.product(name: "LibSECP256k1", package: "secp256k1")],
            path: "src/ecc-helper"),
        .target(
            name: "Bitcoin",
            dependencies: [
                "ECCHelper",
                .product(name: "Crypto", package: "swift-crypto", condition: .when(platforms: [.linux]))
            ],
            path: "src/bitcoin"),
        .testTarget(
            name: "BitcoinTests",
            dependencies: ["Bitcoin"],
            path: "test/bitcoin",
            resources: [
                .copy("data")
            ])
    ]
)
