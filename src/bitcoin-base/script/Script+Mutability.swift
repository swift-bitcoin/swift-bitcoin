import Foundation

/// Mutability.
extension Script: Mutable {

    public init(_ proxy: consuming Proxy) {
        ops = proxy.ops
        unparsable = proxy.unparsable
    }

    public struct Proxy: MutableProxy, ~Copyable {

        public init(_ target: Script) {
            ops = target.ops
            unparsable = target.unparsable
        }

        public var ops: [Script.Operation]
        public var unparsable: Data
    }
}
