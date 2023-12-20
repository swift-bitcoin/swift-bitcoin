import ArgumentParser

@main
struct BitcoinCLI: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "A Bitcoin utility.",
        version: "1.0.0",
        subcommands: [SeedCommand.self],
        defaultSubcommand: SeedCommand.self)
}
