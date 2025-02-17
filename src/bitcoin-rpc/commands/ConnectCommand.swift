import Foundation
import JSONRPC
import BitcoinBase
import BitcoinBlockchain

/// Connects to a peer.
public struct ConnectCommand: RPCCommand, Sendable {

    public init(_ request: JSONRequest) throws(RPCError) {
        precondition(request.method == Self.method)

        guard case let .list(objects) = RPCObject(request.params),
              objects.count > 1,
              case let .string(host) = objects[0],
              case let .integer(port) = objects[1] else {
            throw .init(.invalidParams("host,port"), description: "Host (string) and port (integer) are required.")
        }
        self.host = host
        self.port = port
    }

    public let host: String
    public let port: Int

    public func run(_ request: JSONRequest) async throws -> JSONResponse {
        fatalError("The body of this command must be implemented externally.")
    }

    public static let method = "connect"
    public static let params = "<host> <port>"
    public static let description = "Connects to a peer."
}
