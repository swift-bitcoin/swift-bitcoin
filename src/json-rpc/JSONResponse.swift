import Foundation

private let jsonrpcVersion = "2.0"

public struct JSONResponse: Codable, Sendable {
    public var jsonrpc: String
    public var id: String
    public var result: JSONObject?
    public var error: JSONError?

    public init(id: String, result: JSONObject) {
        self.jsonrpc = jsonrpcVersion
        self.id = id
        self.result = result
        self.error = nil
    }

    public init(id: String, error: JSONError) {
        self.jsonrpc = jsonrpcVersion
        self.id = id
        self.result = nil
        self.error = error
    }

    public init(id: String, errorCode: JSONErrorCode, error: Error) {
        self.init(id: id, error: JSONError(code: errorCode, error: error))
    }

    public init(id: String, result: RPCObject) {
        self.init(id: id, result: JSONObject(result))
    }

    public init(id: String, error: RPCError) {
        self.init(id: id, error: JSONError(error))
    }
}
