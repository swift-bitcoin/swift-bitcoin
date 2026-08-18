import Foundation

/// Mutability.
extension Transaction.Input: Mutable {

    public init(_ proxy: consuming Proxy) {
        outpoint = proxy.outpoint
        sequence = proxy.sequence
        script = proxy.script
        witness = proxy.witness
    }

    public struct Proxy: MutableProxy, ~Copyable {

        public init(_ target: Transaction.Input) {
            outpoint = target.outpoint
            sequence = target.sequence
            script = target.script
            witness = target.witness
        }

        public var outpoint: Outpoint
        public var sequence: Sequence
        public var script: Script
        public var witness: Transaction.Witness
    }
}
