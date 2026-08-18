import Foundation

/// Mutability.
extension Block: Mutable {

    public init(_ proxy: consuming Proxy) {
        version = proxy.version
        previous = proxy.previous
        merkleRoot = proxy.merkleRoot
        time = proxy.time
        target = proxy.target
        nonce = proxy.nonce
        txs = proxy.txs
    }

    public struct Proxy: MutableProxy, ~Copyable {

        public init(_ t: Block) {
            version = t.version
            previous = t.previous
            merkleRoot = t.merkleRoot
            time = t.time
            target = t.target
            nonce = t.nonce
            txs = t.txs
        }

        public var version: Int
        public var previous: Block.ID
        public var merkleRoot: Data
        public var time: Date
        public var target: Int
        public var nonce: Int
        public var txs: [Transaction]
    }
}
