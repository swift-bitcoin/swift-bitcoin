import Foundation

/// Returns a list of peers along with information about them.
public struct GetPeerInfoRPC: RPCCommand, Sendable {

    public typealias Params = Never

    public typealias Result = [ResultItem]

    public struct ResultItem: Codable, Sendable {

        public enum ConnectiontType: Codable, Sendable { case outgoing, incoming }

        public init(id: String, connectionType: ConnectiontType) {
            self.id = id
            self.connectionType = connectionType
        }

        public let id: String
        public let connectionType: ConnectiontType
    }

    public init() { }

    public static let method = "get-peer-info"
    public static let params = ""
    public static let description = "Returns a list of peers along with information about them."
}
