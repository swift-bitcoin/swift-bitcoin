import ArgumentParser

struct DB: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: "",
        discussion: """

        """,
        subcommands: [
            Stats.self, Drop.self, Duplicate.self
        ],
        defaultSubcommand: Stats.self
    )

    @Option var path: String?
}
