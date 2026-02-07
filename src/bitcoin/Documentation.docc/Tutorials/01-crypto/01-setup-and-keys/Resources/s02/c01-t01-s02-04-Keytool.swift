import ArgumentParser

@main
struct Keytool: ParsableCommand {

    static let configuration = CommandConfiguration(
        subcommands: [
            GenerateSecretKey.self
        ]
    )
}
