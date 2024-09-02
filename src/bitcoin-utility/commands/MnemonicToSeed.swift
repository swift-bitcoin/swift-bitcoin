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
        let mnemonicPhrase: MnemonicPhrase
        do {
            mnemonicPhrase = try MnemonicPhrase(mnemonic, passphrase: passphrase, language: language)
        } catch MnemonicPhrase.Error.languageNotSupported {
            throw ValidationError("Invalid language value: language")
        } catch MnemonicPhrase.Error.mnemonicWordNotOnList, MnemonicPhrase.Error.mnemonicInvalidLength, MnemonicPhrase.Error.invalidMnemonicChecksum  {
            throw ValidationError("Invalid mnemonic value: mnemonic")
        } catch {
            throw error
        }
        let result: String
        do {
            result = try mnemonicPhrase.toSeed(passphrase: passphrase)
        } catch {
            throw ValidationError("Invalid UTF-8 passphrase encoding: passphrase")
        }
        print(result)
    }
}
