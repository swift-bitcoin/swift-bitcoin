import ArgumentParser
import BitcoinCrypto
import BitcoinBase
import BitcoinWallet
import Foundation

/// Signs a transaction input using a private key.
struct SignTransaction: ParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: "Signs a transaction input using a private key."
    )

    @Option(name: .shortAndLong, help: "The input to sign.")
    var input: Int

    @Option(name: .shortAndLong, help: "The previous transaction outputs in raw hexadecimal format.")
    var prevout: [String]

    @Option(name: .shortAndLong, help: "The secret key in hex format.")
    var secretKey: String

    @Argument(help: "The raw unsigned or partially signed transaction in hex format.")
    var tx: String

    mutating func run() throws {
        guard let secretKeyData = Data(hex: secretKey) else {
            throw ValidationError("Invalid hexadecimal value: secretKey")
        }
        guard let secretKey = SecretKey(secretKeyData) else {
            throw ValidationError("Invalid secret key data: secretKey")
        }
        guard let txData = Data(hex: tx) else {
            throw ValidationError("Invalid hexadecimal value: tx")
        }
        let tx: Transaction
        do {
            tx = try Transaction(txData)
        } catch {
            throw ValidationError("Invalid raw transaction data: tx")
        }
        let prevouts = try prevout.map {
            guard let prevoutData = Data(hex: $0) else {
                throw ValidationError("Invalid hexadecimal value: prevout")
            }
            guard let prevout = try? TransactionOutput(prevoutData) else {
                throw ValidationError("Invalid raw prevout data: prevout")
            }
            return prevout
        }
        var signer = TransactionSigner(tx: tx, prevouts: prevouts)
        let signed = signer.sign(input: input, with: secretKey)
        print(signed.data.hex)
        destroyECCSigningContext()
    }
}
