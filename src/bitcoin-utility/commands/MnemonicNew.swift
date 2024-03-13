import ArgumentParser
import Bitcoin
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
        print(try Wallet.mnemonicNew(withEntropy: entropy, language: language))
    }
}
