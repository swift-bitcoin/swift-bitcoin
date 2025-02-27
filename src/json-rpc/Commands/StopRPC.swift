public struct StopRPC: RPCCommand, Sendable {

    public typealias Params = Never
    public typealias Result = Never

    public static let method = "stop"
    public static let params = ""
    public static let description = "Stops all services."
}
