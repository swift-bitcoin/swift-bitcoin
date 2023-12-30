import ArgumentParser
import Bitcoin

/// Generates a random seed (entropy) using the system's cryptographically secure algorithm.
///
/// Because it ultimately relies on Swift's SystemRandomNumberGenerator which in turn uses a system-provided cryptographically secure algorithm whenever possible, this command can be considered safe for usage on Apple platforms, Linux, BSD, Windows and others.
struct Seed: ParsableCommand {

    static var configuration = CommandConfiguration(
        abstract: "Generates a random seed (entropy) using the system's cryptographically secure algorithm.",
        discussion: "Because it ultimately relies on Swift's SystemRandomNumberGenerator which in turn uses a system-provided cryptographically secure algorithm whenever possible, this command can be considered safe for usage on Apple platforms, Linux, BSD, Windows and others."
    )

    @Option(name: .shortAndLong, help: "The number of bytes to generate.")
    var bytes = 32

    mutating func run() throws {
        print(Wallet.generateSeed(bytes: bytes))
    }
}
