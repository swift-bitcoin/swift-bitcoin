import ArgumentParser

struct Start: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: "Launch a Bitcoin node instance."
    )

    @OptionGroup var configOptions: ConfigOptions

    mutating func run() async throws(ValidationError) {
        let nodeConfig = try await NodeConfig.loadConfiguration(configOptions)
        do {
            _ = try await ServerApp(nodeConfig)
        } catch {
            throw ValidationError("Error starting server: \(error)")
        }
    }
}

