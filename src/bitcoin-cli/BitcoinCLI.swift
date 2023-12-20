import ArgumentParser

@main
struct BitcoinCLI: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "An all-purpose Bitcoin utility.",
        version: "1.0.0",
        subcommands: [Seed.self])
}
