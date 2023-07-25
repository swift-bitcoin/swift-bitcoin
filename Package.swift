// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "swift-bitcoin",
    products: [
        .library(
            name: "Bitcoin",
            targets: ["Bitcoin"]),
    ],
    targets: [
        .target(
            name: "Bitcoin",
            path: "src"),
        .testTarget(
            name: "BitcoinTests",
            dependencies: ["Bitcoin"],
            path: "test")
    ]
)
