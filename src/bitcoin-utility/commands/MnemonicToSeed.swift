import ArgumentParser
import BitcoinWallet
import Foundation

/// Create a mnemonic seed (BIP39) from entropy.
///
/// WARNING: mnemonic should be created from properly generated entropy.
///
struct MnemonicToSeed: ParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: "Convert a mnemonic phrase (BIP39) into a seed suitable for BIP32 master key generation."
    )

    @Option(name: .shortAndLong, help: "Language code of the word list to use.")
    var language = "en"

    @Option(name: .shortAndLong, help: "An optional passphrase.")
    var passphrase = ""

    @Argument(help: "The mnemonic phrase.")
    var mnemonic: String

    mutating func run() throws {
        print(try Wallet.mnemonicToSeed(mnemonic: mnemonic, passphrase: passphrase, language: language))
    }
}
