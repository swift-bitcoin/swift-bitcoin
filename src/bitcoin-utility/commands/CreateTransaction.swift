import ArgumentParser
import BitcoinBase
import BitcoinWallet
import Foundation

/// Creates an unsigned raw transaction with the specified inputs and outputs.
struct CreateTx: ParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: "Creates an unsigned raw transaction with the specified inputs and outputs."
    )

    @Option(name: .shortAndLong, help: "The transaction identifier of each input.")
    var inputTx: [String]

    @Option(name: .shortAndLong, help: "The ouput index of the corresponding input transaction.")
    var out: [Int]

    @Option(name: .shortAndLong, help: "Address to send to.")
    var address: [String]

    @Option(name: [.customShort("s"), .long], help: "Amount in satoshis (sats) for each of the addresses.")
    var amount: [Amount]

    mutating func run() throws {
        guard inputTx.count == out.count else {
            throw ValidationError("The number of input transactions must match the number of out indices provided.")
        }
        guard address.count == amount.count else {
            throw ValidationError("The number of out addresses must match the number of amounts provided.")
        }
        let outpoints = zip(inputTx, out)
        let addressesAmounts = zip(address, amount)

        let ins = try outpoints.map {
            let (inputTx, out) = $0
            guard let txID = Transaction.ID(hex: inputTx) else {
                throw ValidationError("Invalid input transaction hex: \(inputTx)")
            }
            guard txID.count == Transaction.idLength else {
                throw ValidationError("Invalid transaction identtifier length: \(inputTx)")
            }
            return Transaction.Input(outpoint: .init(tx: txID, out: out))
        }

        let outs = try addressesAmounts.map {
            let (address, amount) = $0
            guard let address = LegacyAddress(address) else {
                throw ValidationError("Invalid address: \(address)")
            }
            return address.out(amount)
        }

        let tx = Transaction(
            ins: ins,
            outs: outs
        )
        print(tx.binaryData.hex)
    }
}
