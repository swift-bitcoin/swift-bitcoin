// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "swift-bitcoin",
    products: [
        .library(
            name: "Bitcoin",
            targets: ["Bitcoin"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.3.0")
    ],
    targets: [
        .target(
            name: "Bitcoin",
            path: "src/bitcoin"),
        .testTarget(
            name: "BitcoinTests",
            dependencies: ["Bitcoin"],
            path: "test/bitcoin")
    ]
)
