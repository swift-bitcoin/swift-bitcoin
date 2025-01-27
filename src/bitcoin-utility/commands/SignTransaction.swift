import ArgumentParser
import BitcoinCrypto
import BitcoinBase
import BitcoinWallet
import Foundation

/// Signs a transaction input using a private key.
struct SignTx: ParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: "Signs a transaction input using a private key."
    )

    @Option(name: .shortAndLong, help: "The input to sign.")
    var txIn: Int

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
        let tx: BitcoinTx
        do {
            tx = try BitcoinTx(binaryData: txData)
        } catch {
            throw ValidationError("Invalid raw transaction data: tx")
        }
        let prevouts = try prevout.map {
            guard let prevoutData = Data(hex: $0) else {
                throw ValidationError("Invalid hexadecimal value: prevout")
            }
            guard let prevout = TxOut(prevoutData) else {
                throw ValidationError("Invalid raw prevout data: prevout")
            }
            return prevout
        }
        let signer = TxSigner(tx: tx, prevouts: prevouts)
        let signed = signer.sign(txIn: txIn, with: secretKey)
        print(signed.binaryData.hex)
        destroyECCSigningContext()
    }
}
