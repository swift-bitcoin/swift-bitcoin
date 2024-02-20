import Foundation

public enum MessageCommand: String, RawRepresentable {
    case version, verack, ping, pong

    static let size = 12 // Data size
}

extension MessageCommand {

    init?(_ data: Data) {
        guard data.count >= Self.size else { return nil }
        let commandDataUntrimmed = data[data.startIndex ..< data.startIndex.advanced(by: Self.size)]
        let commandData = commandDataUntrimmed.reversed().trimmingPrefix(while: { $0 == 0x00 }).reversed()
        let commandRawValue = String(decoding: commandData, as: Unicode.ASCII.self)
        self.init(rawValue: commandRawValue)
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
