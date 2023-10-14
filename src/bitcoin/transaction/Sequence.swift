import Foundation

/// The sequence value of an ``Input``.
public struct Sequence: Equatable {

    public init(_ sequenceValue: Int) {
        self.sequenceValue = sequenceValue
    }

    init?(_ data: Data) {
        guard data.count >= Self.size else {
            return nil
        }
        let rawValue = data.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
        self.init(rawValue)
    }

    private init(_ rawValue: UInt32) {
        self.init(Int(rawValue))
    }

    /// The numeric sequence value.
    public let sequenceValue: Int

    var data: Data {
        withUnsafeBytes(of: rawValue) { Data($0) }
    }
    
    var rawValue: UInt32 { UInt32(sequenceValue) }

    public static let initial = Self(0)

    static let size = MemoryLayout<UInt32>.size
}
