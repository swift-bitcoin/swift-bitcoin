import Foundation
import JSONRPC

/// Stops listening to incoming peer-to-peer connections.
public struct StopP2PCommand: RPCCommand, Sendable {

    public init(_ request: JSONRequest) {
        precondition(request.method == Self.method)
        self.request = request
    }

    let request: JSONRequest

    public func run() async -> JSONResponse {
        fatalError("The body of this command must be implemented externally.")
    }

    public static let method = "stop-p2p"
    public static let params = ""
    public static let description = "Stops listening to incoming peer-to-peer connections."
}
