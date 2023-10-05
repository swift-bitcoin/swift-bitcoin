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
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.3.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0")
    ],
    targets: [
        .target(
            name: "Bitcoin",
            dependencies: [
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
