import Foundation

/// Disconnects peer from node. Returns true if successful.
public struct DisconnectPeerRPC: RPCCommand, Sendable {

    public struct Params: Codable, Sendable {
        public init(peerID: Int /* PeerID */) {
            self.peerID = peerID
        }

        public let peerID: Int /* PeerID */
    }

    public typealias Result = Bool

    public init(_ params: Params) {
        self.params = params
    }

    public let params: Params

    public static let method = "disconnect-peer"
    public static let params = "<peer-id>"
    public static let description = "Disconnects peer from node. Returns true if successful."
}
