public protocol RPCCommand {

    /// The command's method name.
    static var method: String { get }

    /// Parameters' usage – e.g. `"<block_height> [max_amount]"`.
    static var params: String { get }

    /// A short description.
    static var description: String { get }
}
