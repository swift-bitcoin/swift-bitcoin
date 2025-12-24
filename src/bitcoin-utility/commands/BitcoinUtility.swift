import ArgumentParser

@main
struct BitcoinUtility: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "bcutil",
        abstract: "An all-purpose Bitcoin Utility.",
        usage: """
        bcutil <subcommand>
        bcutil help
        bcutil help <subcommand>
        bcutil node help
        bcutil node help <rpc-command>
        """,
        discussion: "Use bcutil to perform off-chain operations as well as to control and use either a single or multiple running Swift Bitcoin nodes (bcnode).",
        version: "1.0.0",
        subcommands: [Node.self, Seed.self, ECNew.self, ECToPublic.self, ECToAddress.self, ScriptToAddress.self, AddressDecode.self, ScriptDecode.self, HDNew.self, HDToPublic.self, HDPrivate.self, HDPublic.self, MnemonicNew.self, MnemonicToSeed.self, ECToWIF.self, WIFToEC.self, MessageSign.self, MessageVerify.self, CreateTransaction.self, SignTransaction.self, DB.self, Chain.self],
        defaultSubcommand: Node.self)}
