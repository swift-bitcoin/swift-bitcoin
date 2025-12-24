public struct ReindexStatusRPC: RPCCommand, Sendable {

    public typealias Params = Never
    public typealias Result = Bool

    public init() {}

    public static let method = "reindex-status"
    public static let params = ""
    public static let description: String = "Returns whether there is currently a re-indexation process taking place."
}
