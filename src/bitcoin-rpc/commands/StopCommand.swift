import Foundation
import JSONRPC

/// Stops the node.
public struct StopCommand: RPCCommand, Sendable {

    public init(_ request: JSONRequest) {
        precondition(request.method == Self.method)
        self.request = request
    }

    let request: JSONRequest

    public func run() async -> JSONResponse {
        fatalError("The body of this command must be implemented externally.")
    }

    public static let method = "stop"
    public static let params = ""
    public static let description = "Stops the node."
}
