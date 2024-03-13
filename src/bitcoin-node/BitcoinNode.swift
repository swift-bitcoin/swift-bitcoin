import ArgumentParser
import NIO

// TODO: Remove these
extension ServerBootstrap: @unchecked Sendable { }
extension ClientBootstrap: @unchecked Sendable { }
extension CommandConfiguration: @unchecked Sendable { }

@main
struct BitcoinNode: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "bcnode",
        abstract: "A Bitcoin server listening for RPC commands.",
        version: "1.0.0",
        subcommands: [Start.self],
        defaultSubcommand: Start.self)
}
