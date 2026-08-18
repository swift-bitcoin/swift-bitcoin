import Foundation

/// Mutability.
extension Outpoint: Mutable {

    public init(_ proxy: consuming Proxy) {
        txID = proxy.txID
        out = proxy.out
    }

    public struct Proxy: MutableProxy, ~Copyable {

        public init(_ target: Outpoint) {
            txID = target.txID
            out = target.out
        }

        public var txID: Transaction.ID
        public var out: Int
    }
}
