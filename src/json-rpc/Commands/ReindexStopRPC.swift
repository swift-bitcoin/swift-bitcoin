public struct ReindexStopRPC: RPCCommand, Sendable {

    public typealias Params = Never
    public typealias Result = Never

    public init() {}

    public static let method = "reindex-stop"
    public static let params = ""
    public static let description = "Interrupts the running re-indexation process."
}
