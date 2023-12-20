import Foundation

/// A reference to an unspent transation output (aka _UTXO_).
public struct UnspentOutput: Equatable {
    let output: TransactionOutput
    let height: Int
    let isCoinbase: Bool
}
