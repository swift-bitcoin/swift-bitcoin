import Foundation

/// Mutability.
extension Transaction: Mutable {

    public init(_ proxy: consuming Proxy) {
        version = proxy.version
        locktime = proxy.locktime
        ins = proxy.ins
        outs = proxy.outs
    }

    public struct Proxy: MutableProxy, ~Copyable {

        public init(_ target: Transaction) {
            version = target.version
            locktime = target.locktime
            ins = target.ins
            outs = target.outs
        }

        public var version: Version
        public var locktime: Locktime
        public var ins: [Transaction.Input]
        public var outs: [TransactionOutput]
    }
}
