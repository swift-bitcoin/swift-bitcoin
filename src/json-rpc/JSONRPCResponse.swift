import Foundation

public struct JSONRPCResponse: Codable, Sendable {

    public struct Error: Swift.Error, Codable, Equatable, Sendable {

        public enum ErrorCode: Int, Codable, Sendable {
            case parseError = -32700
            case invalidRequest = -32600
            case methodNotFound = -32601
            case invalidParams = -32602
            case internalError = -32603
            case other = -32000
        }

        public enum CodingKeys: CodingKey {
            case code, message, data
        }

        public init(_ code: ErrorCode, _ message: String) {
            self.code = code
            self.message = message
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            code = try container.decode(ErrorCode.self, forKey: .code)
            message = try container.decode(String.self, forKey: .message)
        }

        public var code: ErrorCode
        public var message: String

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(code, forKey: .code)
            try container.encode(message, forKey: .message)
            try container.encode(Never?.none, forKey: .data)
        }
    }

    public enum CodingKeys: CodingKey {
        case jsonrpc, id, result, error
    }

    public init(id: UUID, result: Result) {
        self.id = id
        self.result = result
        self.error = nil
    }

    public init(id: UUID, error: Error) {
        self.id = id
        self.result = nil
        self.error = error
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let jsonrpc = try container.decode(String.self, forKey: .jsonrpc)
        guard jsonrpc == JSONRPCRequest.jsonRPCVersion else {
            throw DecodingError.typeMismatch(Self.self, .init(codingPath: decoder.codingPath, debugDescription: "Unsupported JSON-RPC version '\(jsonrpc)'. Only version \(JSONRPCRequest.jsonRPCVersion) is supported."))
        }
        id = try container.decode(UUID.self, forKey: .id)
        result = try container.decodeIfPresent(Result.self, forKey: .result)
        error = try container.decodeIfPresent(Error.self, forKey: .error)
    }

    public let id: UUID
    public let result: Result?
    public var error: Error?

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(JSONRPCRequest.jsonRPCVersion, forKey: .jsonrpc)
        try container.encode(id, forKey: .id)
        try container.encode(result, forKey: .result)
        try container.encode(error, forKey: .error)
    }
}
