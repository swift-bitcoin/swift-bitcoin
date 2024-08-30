import ArgumentParser
import BitcoinWallet
import Foundation

/// Create a mnemonic seed (BIP39) from entropy.
///
/// WARNING: mnemonic should be created from properly generated entropy.
///
struct MnemonicNew: ParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: "Create a mnemonic seed (BIP39) from entropy.",
        discussion: "WARNING: mnemonic should be created from properly generated entropy."
    )

    @Option(name: .shortAndLong, help: "Language code of the word list to use.")
    var language = "en"

    @Argument(help: "Entropy in hexadecimal binary representation.")
    var entropy: String

    mutating func run() throws {
        let entropyHex = entropy
        guard let entropy = Data(hex: entropyHex) else {
            throw ValidationError("Invalid hexadecimal value: entropy")
        }
        let mnemonicPhrase: MnemonicPhrase
        do {
            mnemonicPhrase = try MnemonicPhrase(entropy: entropy, language: language)
        } catch {
            throw ValidationError("Invalid value: entropy / language")
        }
        let result = mnemonicPhrase.mnemonic
        print(result)
    }
}
