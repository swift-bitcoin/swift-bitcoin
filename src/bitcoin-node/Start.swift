import ArgumentParser

struct Start: AsyncParsableCommand {

    static var configuration = CommandConfiguration(
        abstract: "Launch a Bitcoin node instance."
    )

    @Option(name: .shortAndLong, help: "The TCP port number to bind the server instance to.")
    var port: Int = 8333

    mutating func run() async throws {
        try await launchNode(port: port)
    }
}
