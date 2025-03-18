import Foundation

public typealias ProprietaryInfo = [ProprietaryID : [ProprietaryKey : ProprietaryValue]]
public typealias ProprietaryID = Data
public typealias ProprietaryKeyType = Int
public typealias ProprietaryValue = Data

/// Proprietary key.
public struct ProprietaryKey: Hashable, Sendable {

    /// Creates a new proprietary key.
    /// - Parameters:
    ///   - type: Key type. Must be greater than 0.
    ///   - data: Ky data. Can be empty.
    public init(type: ProprietaryKeyType, data: Data) {
        precondition(type >= 0)
        self.type = type
        self.data = data
    }

    init(_ subkey: PSBTMap.Key) {
        type = subkey.type
        data = subkey.data
    }

    let type: ProprietaryKeyType
    let data: Data
}
