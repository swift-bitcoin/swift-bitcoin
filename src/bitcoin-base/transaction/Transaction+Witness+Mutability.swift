import Foundation

/// Mutability.
extension Transaction.Witness: Mutable {

    public init(_ proxy: consuming Proxy) {
        stack = proxy.stack
    }

    public struct Proxy: MutableProxy, ~Copyable {

        public init(_ target: Transaction.Witness) {
            stack = target.stack
        }

        public var stack: [Data]
    }
}
