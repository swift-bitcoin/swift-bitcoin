import BitcoinBase

/// Generic miniscript expression.
///
/// Every miniscript expression has one of four basic types: ``ExpB``, ``ExpK``, ``ExpV``, ``ExpW``.
public protocol MiniscriptExp: Sendable, CustomStringConvertible {
    var compiled: [Script.Operation] { get }
}
