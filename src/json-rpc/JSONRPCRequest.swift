import Foundation

public struct JSONRPCRequest: Codable, Sendable {

    enum CodingKeys: CodingKey {
        case jsonrpc, id, method, params
    }

    public init(_ params: Params) {
        self.id = UUID()
        self.params = params
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let jsonrpc = try container.decode(String.self, forKey: .jsonrpc)
        guard jsonrpc == Self.jsonRPCVersion else {
            throw DecodingError.typeMismatch(Self.self, .init(codingPath: decoder.codingPath, debugDescription: "Unsupported JSON-RPC version '\(jsonrpc)'. Only version \(Self.jsonRPCVersion) is supported."))
        }
        id = try container.decode(UUID.self, forKey: .id)
        let method = try container.decode(String.self, forKey: .method)
        let superDecoder = try container.superDecoder(forKey: .params)
        params = try Params(from: superDecoder, method: method)
    }

    public let id: UUID
    public let params: Params

    public var method: String { params.method }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.jsonRPCVersion, forKey: .jsonrpc)
        try container.encode(id, forKey: .id)
        try container.encode(params.method, forKey: .method)
        try container.encode(params, forKey: .params)
    }

    public static let jsonRPCVersion = "2.0"
}
