import Foundation

public struct RPCError: Error {
    public init(_ kind: Kind, description: String? = nil) {
        self.kind = kind
        self.description = description
    }

    public let kind: Kind
    public let description: String?

    public enum Kind: Error {
        case invalidMethod
        case invalidParams(String)
        case invalidRequest(String)
        case applicationError(String)
    }
}
