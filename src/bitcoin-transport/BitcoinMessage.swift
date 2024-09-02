import Foundation
import BitcoinCrypto
import BitcoinBlockchain

public struct BitcoinMessage: Equatable, Sendable {

    public init(_ command: MessageCommand, payload: Data = .init(), network: NodeNetwork = .regtest) {
        self.network = network
        self.command = command
        self.payloadSize = payload.count
        let payloadHash = Data(Hash256.hash(data: payload))
        self.checksum = payloadHash.withUnsafeBytes {
            $0.loadUnaligned(as: UInt32.self)
        }
        self.payload = payload
    }

    public let network: NodeNetwork
    public let command: MessageCommand
    private let payloadSize: Int
    public let checksum: UInt32
    public let payload: Data

    public var isChecksumOk: Bool {
        let hash = Data(Hash256.hash(data: payload))
        let realChecksum = hash.withUnsafeBytes {
            $0.loadUnaligned(as: UInt32.self)
        }
        return checksum == realChecksum
    }

    public static let baseSize = 24
    public static let payloadSizeStartIndex = 16
    public static let payloadSizeEndIndex = 20
}

extension BitcoinMessage {

    public init?(_ data: Data) {
        guard data.count >= Self.baseSize else { return nil }
        var data = data
        guard let network = NodeNetwork(data) else { return nil }
        self.network = network
        data = data.dropFirst(NodeNetwork.size)
        guard let command = MessageCommand(data) else { return nil }
        self.command = command
        data = data.dropFirst(MessageCommand.size)

        guard data.count >= MemoryLayout<UInt32>.size else { return nil }
        let payloadSize = Int(data.withUnsafeBytes {
            $0.loadUnaligned(as: UInt32.self)
        })
        self.payloadSize = payloadSize
        data = data.dropFirst(MemoryLayout<UInt32>.size)

        guard data.count >= MemoryLayout<UInt32>.size else { return nil }
        self.checksum = data.withUnsafeBytes {
            $0.loadUnaligned(as: UInt32.self)
        }
        data = data.dropFirst(MemoryLayout<UInt32>.size)

        guard data.count >= payloadSize else { return nil }
        self.payload = data.prefix(payloadSize)
    }

    var size: Int {
        Self.baseSize + payload.count
    }

    public var data: Data {
        var ret = Data(count: size)
        var offset = ret.addData(network.data)
        offset = ret.addData(command.data, at: offset)
        offset = ret.addBytes(UInt32(payloadSize), at: offset)
        offset = ret.addBytes(checksum, at: offset)
        ret.addData(payload, at: offset)
        return ret
    }
}
