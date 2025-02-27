/// Stops listening to incoming peer-to-peer connections.
public struct StopP2PRPC: RPCCommand, Sendable {

    public typealias Params = Never
    public typealias Result = Never

    public static let method = "stop-p2p"
    public static let params = ""
    public static let description = "Stops listening to incoming peer-to-peer connections."
}
