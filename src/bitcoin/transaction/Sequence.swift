import Foundation

/// The sequence value of an ``Input``.
public struct Sequence: Equatable {

    public init(_ sequenceValue: Int) {
        self.sequenceValue = sequenceValue
    }

    /// The numeric sequence value.
    public let sequenceValue: Int

    var data: Data {
        withUnsafeBytes(of: rawValue) { Data($0) }
    }
    
    private var rawValue: UInt32 { UInt32(sequenceValue) }

    static let size = MemoryLayout<UInt32>.size
}
