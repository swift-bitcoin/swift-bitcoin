import Foundation
import Bitcoin
import CryptoUtils

public struct Message: Equatable {

    public init(network: Network, command: String, payload: Data) {
        self.network = network
        self.command = command
        self.payloadSize = payload.count
        let payloadHash = hash256(payload)
        self.checksum = payloadHash.withUnsafeBytes {
            $0.loadUnaligned(as: UInt32.self)
        }
        self.payload = payload
    }

    public init?(_ data: Data) {
        guard data.count >= Self.baseSize else { return nil }
        var remainingData = data
        guard let network = Network(remainingData) else { return nil }
        self.network = network
        remainingData = remainingData.dropFirst(Network.size)
        let commandDataUntrimmed = remainingData[remainingData.startIndex ..< remainingData.startIndex.advanced(by: Self.commandSize)]
        let commandData = commandDataUntrimmed.reversed().trimmingPrefix(while: { $0 == 0x00 }).reversed()
        self.command = String(decoding: commandData, as: Unicode.ASCII.self)
        remainingData = remainingData.dropFirst(commandDataUntrimmed.count)

        guard remainingData.count >= MemoryLayout<UInt32>.size else { return nil }
        let payloadSize = Int(remainingData.withUnsafeBytes {
            $0.loadUnaligned(as: UInt32.self)
        })
        self.payloadSize = payloadSize
        remainingData = remainingData.dropFirst(MemoryLayout<UInt32>.size)

        guard remainingData.count >= MemoryLayout<UInt32>.size else { return nil }
        self.checksum = remainingData.withUnsafeBytes {
            $0.loadUnaligned(as: UInt32.self)
        }
        remainingData = remainingData.dropFirst(MemoryLayout<UInt32>.size)

        guard remainingData.count >= payloadSize else { return nil }
        self.payload = Data(remainingData[..<remainingData.startIndex.advanced(by: payloadSize)])
    }

    public let network: Network
    public let command: String
    public let payloadSize: Int
    public let checksum: UInt32
    public let payload: Data

    public var size: Int {
        Self.baseSize + payload.count
    }

    public var data: Data {
        let commandData = command.data(using: .ascii)!
        let commandPaddingData = Data(repeating: 0, count: Self.commandSize - commandData.count)

        var ret = Data(count: size)
        var offset = ret.addData(network.data)
        offset = ret.addData(commandData, at: offset)
        offset = ret.addData(commandPaddingData, at: offset)
        offset = ret.addBytes(UInt32(payloadSize), at: offset)
        offset = ret.addBytes(checksum, at: offset)
        ret.addData(payload, at: offset)
        return ret
    }

    public var isChecksumOk: Bool {
        let hash = hash256(payload)
        let realChecksum = hash.withUnsafeBytes {
            $0.load(as: UInt32.self)
        }
        return checksum == realChecksum
    }

    public static let baseSize = 24
    public static let payloadSizeStartIndex = 16
    public static let payloadSizeEndIndex = 20
    static let commandSize = 12
}

public enum Network: UInt32 {

    public init?(_ data: Data) {
        guard data.count >= MemoryLayout<RawValue>.size else { return nil }
        let rawValue = data.withUnsafeBytes {
            $0.loadUnaligned(as: RawValue.self)
        }
        self.init(rawValue: rawValue)
    }

    case main = 0xD9B4BEF9, regtest = 0xDAB5BFFA

    var data: Data {
        Data(value: rawValue)
    }

    static let size = MemoryLayout<RawValue>.size
}
