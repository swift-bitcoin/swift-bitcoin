import ArgumentParser
import Bitcoin
import Foundation

/// Decodes a script into its assembly textual representation.
struct ScriptDecode: ParsableCommand {

    static var configuration = CommandConfiguration(
        abstract: "Decodes a script into its assembly textual representation.."
    )

    @Option(name: .shortAndLong, help: "The signature version of the script.")
    var version = SigVersion.base

    @Argument(help: "The serialized script to decode in hex format.")
    var script: String

    mutating func run() throws {
        print(try Wallet.decodeScript(script: script, sigVersion: version))
    }
}
