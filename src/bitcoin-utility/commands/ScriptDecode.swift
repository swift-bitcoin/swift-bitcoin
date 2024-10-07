import ArgumentParser
import BitcoinBase
import BitcoinWallet
import Foundation

/// Decodes a script into its assembly textual representation.
struct ScriptDecode: ParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: "Decodes a script into its assembly textual representation.."
    )

    @Option(name: .shortAndLong, help: "The signature version of the script.")
    var version = SigVersion.base

    @Argument(help: "The serialized script to decode in hex format.")
    var script: String

    mutating func run() throws {
        let scriptHex = script
        guard let scriptData = Data(hex: scriptHex) else {
            throw ValidationError("Invalid hex format: script")
        }
        let script = BitcoinScript(scriptData)
        print(script.asm(version))
    }
}
