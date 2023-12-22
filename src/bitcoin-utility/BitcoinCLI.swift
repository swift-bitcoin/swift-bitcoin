import ArgumentParser

@main
@OptionGroup
struct BitcoinUtility: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "bcutil",
        abstract: "An all-purpose Bitcoin Utility.",
        version: "1.0.0",
        subcommands: [Seed.self, HDNew.self, HDToPublic.self, HDPrivate.self, HDPublic.self])
}
