public struct ReindexRPC: RPCCommand, Sendable {

    public typealias Params = Never
    public typealias Result = Never

    public init() {}

    public static let method = "reindex"
    public static let params = ""
    public static let description = "Recreates the block index, chain state (coins) and block undo data files."
}
