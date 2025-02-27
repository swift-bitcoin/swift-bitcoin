/// Starts listening to peer-to-peer connections.
public struct StartP2PRPC: RPCCommand, Sendable {

    public struct Params: Codable, Sendable {
        public init(host: String, port: Int) {
            self.host = host
            self.port = port
        }

        public let host: String
        public let port: Int
    }

    public typealias Result = Bool

    public static let method = "start-p2p"
    public static let params = "<remote-address> <remote-port>"
    public static let description = "Starts listening to peer-to-peer connections."
}
