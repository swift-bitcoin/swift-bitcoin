import Foundation
import BitcoinBase

/// A common interface for all types of Bitcoin addresses: legacy, segwit and taproot. An address can be decoded from a string and must be able to produce a transaction output for a given satoshi amount.
public protocol AddressProtocol: CustomStringConvertible, Equatable, Sendable {

    /// Decodes a string representation of an address into a Bitcoin address instance.
    init?(_ address: String)

    /// Generates an output script.
    var script: Script { get }
}

extension AddressProtocol {

    /// Generates an output for use in transactions.
    public func out(_ value: Amount) -> TransactionOutput {
        .init(value: value, script: script)
    }
}
