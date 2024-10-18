import Foundation

public enum RPCObject: Equatable {
    case none
    case string(String)
    case integer(Int)
    case double(Double)
    case bool(Bool)
    case list([RPCObject])
    case dictionary([String: RPCObject])

    public init(_ value: String) {
        self = .string(value)
    }

    public init(_ value: Int) {
        self = .integer(value)
    }

    public init(_ value: Double) {
        self = .double(value)
    }

    public init(_ value: Bool) {
        self = .bool(value)
    }

    public init(_ value: [String]) {
        self = .list(value.map { RPCObject($0) })
    }

    public init(_ value: [Int]) {
        self = .list(value.map { RPCObject($0) })
    }

    public init(_ value: [String: String]) {
        self = .dictionary(value.mapValues { RPCObject($0) })
    }

    public init(_ value: [String: Int]) {
        self = .dictionary(value.mapValues { RPCObject($0) })
    }

    public init(_ value: [RPCObject]) {
        self = .list(value)
    }

    public init(_ object: JSONObject) {
        switch object {
        case .none:
            self = .none
        case .string(let value):
            self = .string(value)
        case .integer(let value):
            self = .integer(value)
        case .double(let value):
            self = .double(value)
        case .bool(let value):
            self = .bool(value)
        case .list(let value):
            self = .list(value.map { RPCObject($0) })
        case .dictionary(let value):
            self = .dictionary(value.mapValues { RPCObject($0) })
        }
    }
}
