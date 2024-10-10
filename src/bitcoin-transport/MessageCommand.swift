import Foundation

public enum MessageCommand: String, RawRepresentable, Sendable {
    case version, verack, ping, pong

    /// BIP339
    case wtxidrelay
    case getaddr

    /// BIP155
    case sendaddrv2, addrv2

    /// BIP152
    /// ``SendCompactMessage``
    case sendcmpct

    case getheaders
    case headers

    /// BIP133
    case feefilter

    case inv, getdata, notfound, block
    case unknown

    static let size = 12 // Data size

    init(tentativeRawValue: String) {
        // Messages received after connection to server: version, wtxidrelay sendaddrv2, verack, sendcmpct, ping, getheaders, feefilter
        self = Self(rawValue: tentativeRawValue) ?? .unknown
    }
}

extension MessageCommand {

    init?(_ data: Data) {
        guard data.count >= Self.size else { return nil }
        let commandDataUntrimmed = data.prefix(Self.size)
        let commandData = commandDataUntrimmed.reversed().trimmingPrefix(while: { $0 == 0x00 }).reversed()
        let commandRawValue = String(decoding: commandData, as: Unicode.ASCII.self)
        self.init(tentativeRawValue: commandRawValue)
    }

    var data: Data {
        var ret = Data(count: Self.size)
        let commandData = rawValue.data(using: .ascii)!
        let offset = ret.addData(commandData)
        let commandPaddingData = Data(repeating: 0, count: Self.size - commandData.count)
        ret.addData(commandPaddingData, at: offset)
        return ret
    }
}
