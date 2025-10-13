/// Connects to a peer. Returns the new peer's ID if successful.

import Foundation

public struct ConnectRPC: RPCCommand, Sendable {

    public struct Params: Codable, Sendable {
        public init(host: String, port: Int) {
            self.host = host
            self.port = port
        }

        public let host: String
        public let port: Int
    }

    public typealias Result = Int // PeerID

    public init(_ params: Params) {
        self.params = params
    }

    public let params: Params

    public static let method = "connect"
    public static let params = "<host> <port>"
    public static let description = "Connects to a peer. Returns the new peer's ID if successful."
}
