import ArgumentParser

struct BitcoinUtility: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "bcutil",
        abstract: "An all-purpose Bitcoin Utility.",
        version: "1.0.0",
        subcommands: [Seed.self, HDNew.self, HDToPublic.self, HDPrivate.self, HDPublic.self, MnemonicNew.self, MnemonicToSeed.self])
}
