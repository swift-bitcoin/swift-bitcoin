public protocol MutableProxy: ~Copyable {
    /// Explicitly bind the proxy back to its immutable layout type
    associatedtype Target: Mutable where Target.Proxy == Self

    init(_ target: Target)
}

public protocol Mutable {
    /// Bind the target back to its non-copyable proxy.
    ///
    /// While cannot be enforced, it is highly recommended that the proxy itself is of an ~Copyable type.
    associatedtype Proxy: MutableProxy, ~Copyable where Proxy.Target == Self

    init(_ proxy: consuming Proxy)
}

extension Mutable {
    public func mutating(_ mutate: (inout Proxy) -> ()) -> Self {
        var proxy = Proxy(self)
        mutate(&proxy)
        return Self(proxy)
    }

    public mutating func mutate(_ mutate: (inout Proxy) -> ()) {
        self = mutating(mutate)
    }
}
