import Foundation

/// Mutability.
extension TransactionOutput: Mutable {

    public init(_ proxy: consuming Proxy) {
        value = proxy.value
        script = proxy.script
    }

    public struct Proxy: MutableProxy, ~Copyable {

        public init(_ target: TransactionOutput) {
            value = target.value
            script = target.script
        }

        public var value: Amount
        public var script: Script
    }
}
