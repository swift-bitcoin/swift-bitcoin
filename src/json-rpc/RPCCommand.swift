public protocol RPCCommand: Sendable {

    associatedtype Params: Codable
    associatedtype Result: Codable

    /// The command's method name.
    static var method: String { get }

    /// Parameters' usage – e.g. `"<block_height> [max_amount]"`.
    static var params: String { get }

    /// A short description.
    static var description: String { get }
}
