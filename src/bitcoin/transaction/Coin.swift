import Foundation

/// A reference to an unspent transation output (aka _UTXO_).
public struct Coin: Equatable {
    let output: Output
    let height: Int
    let isCoinbase: Bool
}
