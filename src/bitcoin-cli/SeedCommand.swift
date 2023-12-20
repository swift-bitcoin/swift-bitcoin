import ArgumentParser

struct SeedCommand: ParsableCommand {

    static var configuration = CommandConfiguration(
        abstract: "Generate a seed (entropy)."
    )

    @Option(name: .shortAndLong, help: "The number of bytes to generate.")
    var bytes = 32

    mutating func run() throws {
        fatalError() // Unimplemented
    }
}
