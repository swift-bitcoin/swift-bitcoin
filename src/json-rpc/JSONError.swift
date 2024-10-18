import Foundation

public struct JSONError: Codable, Sendable {
    public var code: Int
    public var message: String
    public var data: Dictionary<String, String>?

    public init(code: Int, message: String) {
        self.code = code
        self.message = message
        self.data = nil
    }

    public init(code: JSONErrorCode, message: String) {
        self.init(code: code.rawValue, message: message)
    }

    public init(code: JSONErrorCode, error: Error) {
        self.init(code: code, message: String(describing: error))
    }

    public init(_ error: RPCError) {
        switch error.kind {
        case .invalidMethod:
            self.init(code: .methodNotFound, message: error.description ?? "invalid method")
        case .invalidParams:
            self.init(code: .invalidParams, message: error.description ?? "invalid params")
        case .invalidRequest:
            self.init(code: .invalidRequest, message: error.description ?? "invalid request")
        case .applicationError(let description):
            self.init(code: .other, message: error.description ?? description)
        }
    }
}
