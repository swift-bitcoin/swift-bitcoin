import Foundation

/// The sequence value of a ``TransactionInput``.
///
/// On version 2 transactions this field is used to indicate a lock time relative to the output being spent. Until the coin is as old as the indicated number of blocks or time interval the transaction will not be validated or mined.
public struct InputSequence: Equatable, Sendable {
    
    /// Creates a sequence with a specific value. Use only in verion 1 transactions.
    /// - Parameter sequenceValue: The number value of this sequence field.
    public init(_ sequenceValue: Int) {
        self.sequenceValue = sequenceValue
    }
    
    /// Creates a sequence from a relative lock time specified in blocks (version 2 transactions only).
    /// - Parameter blocks: How many blocks need to be mined from the creation of the previous output.
    public init?(locktimeBlocks blocks: Int) {
        guard blocks >= Self.zeroLocktimeBlocks.sequenceValue && blocks <= Self.locktimeMask else {
            return nil
        }
        self.init(blocks)
    }
    
    /// Creates a sequence from a relative locktime specified as a seconds interval (coin age). Use only with version 2 transactions.
    /// - Parameter seconds: How many seconds need to pass from the creation of the previous output.
    public init?(locktimeSeconds seconds: Int) {
        guard seconds >= Self.initial.sequenceValue && seconds <= Self.maxSeconds else {
            return nil
        }
        self.init(seconds >> Self.granularity)
    }

    /// The numeric sequence value.
    public let sequenceValue: Int

    public var isLocktimeDisabled: Bool {
        sequenceValue & Self.locktimeDisableFlag != 0
    }

    public var isLocktimeBlocks: Bool {
        sequenceValue & Self.locktimeClockFlag == 0
    }

    public var locktimeBlocks: Int? {
        guard !isLocktimeDisabled && isLocktimeBlocks else {
            return nil
        }
        return sequenceValue & Self.locktimeMask
    }

    public var locktimeSeconds: Int? {
        guard !isLocktimeDisabled && !isLocktimeBlocks else {
            return nil
        }
        return (sequenceValue & Self.locktimeMask) << Self.granularity
    }

    var rawValue: UInt32 { UInt32(sequenceValue) }

    public static let initial = Self(0)
    public static let secondFinal = Self(0xfffffffe)
    public static let final = Self(0xffffffff)
    public static let locktimeDisabled  = Self(locktimeDisableFlag)
    public static let zeroLocktimeBlocks = initial
    public static let maxLocktimeBlocks = Self(locktimeMask)
    public static let zeroLocktimeSeconds = Self(locktimeClockFlag)
    public static let maxLocktimeSeconds = Self(locktimeClockFlag | locktimeMask)

    /// BIP112
    static let maxCSVArgument = 0x0180000000 // 3 << 31

    private static let locktimeMask = 0xffff
    private static let locktimeClockFlag = 0x400000 // 1 << 22
    private static let locktimeDisableFlag = 0x80000000 // 1 << 31
    private static let granularity = 9 // Base 2 exponent: pow(2, 9) = 512 seconds
    private static let maxSeconds = locktimeMask << granularity
}

/// Data extensions.
extension InputSequence {

    init?(_ data: Data) {
        guard data.count >= Self.size else {
            return nil
        }
        let rawValue = data.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
        self.init(Int(rawValue))
    }

    var data: Data {
        Data(value: rawValue)
    }

    static let size = MemoryLayout<UInt32>.size
}
