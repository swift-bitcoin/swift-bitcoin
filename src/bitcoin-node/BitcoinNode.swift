import ArgumentParser

@main
struct BitcoinNode: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "bcnode",
        abstract: "A Bitcoin server listening for RPC commands.",
        version: "1.0.0",
        subcommands: [Start.self],
        defaultSubcommand: Start.self)
}
