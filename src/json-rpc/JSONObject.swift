import Foundation

public enum JSONObject: Codable, Sendable {
    case none
    case string(String)
    case integer(Int)
    case double(Double)
    case bool(Bool)
    case list([JSONObject])
    case dictionary([String: JSONObject])

    public init(_ object: RPCObject) {
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
            self = .list(value.map { JSONObject($0) })
        case .dictionary(let value):
            self = .dictionary(value.mapValues { JSONObject($0) })
        }
    }
}

public extension JSONObject {
    enum CodingKeys: CodingKey {
        case string
        case integer
        case double
        case bool
        case list
        case dictionary
    }

    // FIXME: is there a more elegant way?
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        do {
            let value = try container.decode(String.self)
            self = .string(value)
        } catch {
            do {
                let value = try container.decode(Int.self)
                self = .integer(value)
            } catch {
                do {
                    let value = try container.decode(Double.self)
                    self = .double(value)
                } catch {
                    do {
                        let value = try container.decode(Bool.self)
                        self = .bool(value)
                    } catch {
                        do {
                            let value = try container.decode([JSONObject].self)
                            self = .list(value)
                        } catch {
                            do {
                                let value = try container.decode([String: JSONObject].self)
                                self = .dictionary(value)
                            } catch {
                                self = .none
                            }
                        }
                    }
                }
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .none:
            break
        case .string(let value):
            try container.encode(value)
        case .integer(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .list(let value):
            try container.encode(value)
        case .dictionary(let value):
            try container.encode(value)
        }
    }
}
