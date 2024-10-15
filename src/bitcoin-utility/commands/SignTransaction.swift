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
    var transaction: String

    mutating func run() throws {
        guard let secretKeyData = Data(hex: secretKey) else {
            throw ValidationError("Invalid hexadecimal value: secretKey")
        }
        guard let secretKey = SecretKey(secretKeyData) else {
            throw ValidationError("Invalid secret key data: secretKey")
        }
        guard let transactionData = Data(hex: transaction) else {
            throw ValidationError("Invalid hexadecimal value: transaction")
        }
        guard let transaction = BitcoinTransaction(transactionData) else {
            throw ValidationError("Invalid raw transaction data: transaction")
        }
        let prevouts = try prevout.map {
            guard let prevoutData = Data(hex: $0) else {
                throw ValidationError("Invalid hexadecimal value: prevout")
            }
            guard let prevout = TransactionOutput(prevoutData) else {
                throw ValidationError("Invalid raw prevout data: prevout")
            }
            return prevout
        }
        let signer = TransactionSigner(transaction: transaction, prevouts: prevouts)
        let signed = signer.sign(input: input, with: secretKey)
        print(signed.data.hex)
        destroyECCSigningContext()
    }
}
