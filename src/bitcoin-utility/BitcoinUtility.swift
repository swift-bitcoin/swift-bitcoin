import ArgumentParser
import NIO

@main
struct BitcoinUtility: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "bcutil",
        abstract: "An all-purpose Bitcoin Utility.",
        version: "1.0.0",
        subcommands: [Node.self, Seed.self, ECNew.self, ECToPublic.self, ECToAddress.self, ScriptToAddress.self, ScriptDecode.self, HDNew.self, HDToPublic.self, HDPrivate.self, HDPublic.self, MnemonicNew.self, MnemonicToSeed.self, ECToWIF.self, WIFToEC.self, MessageSign.self, MessageVerify.self, CreateTransaction.self],
        defaultSubcommand: Node.self)}
