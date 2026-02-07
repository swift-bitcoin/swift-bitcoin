// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "BitcoinKeyTool",
    platforms: [.macOS(.v26)], // Add this if you're building for the Mac
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.0"),
        .package(url: "https://github.com/swift-bitcoin/swift-bitcoin", from: "0.1.0")
    ],
    targets: [
        .executableTarget(
            name: "keytool",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Bitcoin", package: "swift-bitcoin")
            ]
        )
    ]
)
