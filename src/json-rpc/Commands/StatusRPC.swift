/// Displays status for all of the node's services.
public struct StatusRPC: RPCCommand, Sendable {

    public typealias Params = Never

    public struct Result: Codable, Sendable {

        public struct RPCService: Codable, Sendable {

            public init(listening: Bool, host: String, port: Int, overallConnections: Int, activeConnections: Int) {
                self.listening = listening
                self.host = host
                self.port = port
                self.overallConnections = overallConnections
                self.activeConnections = activeConnections
            }

            let listening: Bool
            let host: String?
            let port: Int?
            let overallConnections: Int
            let activeConnections: Int
        }

        public struct P2PService: Codable, Sendable {

            public init(running: Bool, listening: Bool, host: String?, port: Int?, overallConnections: Int, sessionConnections: Int, activeConnections: Int) {
                self.running = running
                self.listening = listening
                self.host = host
                self.port = port
                self.overallConnections = overallConnections
                self.sessionConnections = sessionConnections
                self.activeConnections = activeConnections
            }

            let running: Bool
            let listening: Bool
            let host: String?
            let port: Int?
            let overallConnections: Int
            let sessionConnections: Int
            let activeConnections: Int
        }

        public struct P2PClient: Codable, Sendable {

            public init(running: Bool, connected: Bool, remoteHost: String, remotePort: Int, localPort: Int?) {
                self.running = running
                self.connected = connected
                self.remoteHost = remoteHost
                self.remotePort = remotePort
                self.localPort = localPort
            }

            public var index = -1
            let running: Bool
            let connected: Bool
            let remoteHost: String
            let remotePort: Int
            let localPort: Int?
        }

        public init(rpcStatus: StatusRPC.Result.RPCService, p2pStatus: StatusRPC.Result.P2PService, p2pClientStatus: [StatusRPC.Result.P2PClient]) {
            self.rpcStatus = rpcStatus
            self.p2pStatus = p2pStatus
            self.p2pClientStatus = p2pClientStatus
        }

        let rpcStatus: RPCService
        let p2pStatus: P2PService
        let p2pClientStatus: [P2PClient]
    }

    public init() { }

    public static let method = "status"
    public static let params = ""
    public static let description = "Displays status for all of the node's services."
}
