import Foundation
import Bitcoin
import BitcoinCrypto

struct BitcoinMessage: Equatable {

    init(network: NodeNetwork, command: MessageCommand, payload: Data) {
        self.network = network
        self.command = command
        self.payloadSize = payload.count
        let payloadHash = hash256(payload)
        self.checksum = payloadHash.withUnsafeBytes {
            $0.loadUnaligned(as: UInt32.self)
        }
        self.payload = payload
    }

    let network: NodeNetwork
    let command: MessageCommand
    let payloadSize: Int
    let checksum: UInt32
    let payload: Data

    var isChecksumOk: Bool {
        let hash = hash256(payload)
        let realChecksum = hash.withUnsafeBytes {
            $0.load(as: UInt32.self)
        }
        return checksum == realChecksum
    }

    static let baseSize = 24
    static let payloadSizeStartIndex = 16
    static let payloadSizeEndIndex = 20
}

extension BitcoinMessage {

    init?(_ data: Data) {
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
        self.payload = Data(data[..<data.startIndex.advanced(by: payloadSize)])
    }

    var size: Int {
        Self.baseSize + payload.count
    }

    var data: Data {
        var ret = Data(count: size)
        var offset = ret.addData(network.data)
        offset = ret.addData(command.data, at: offset)
        offset = ret.addBytes(UInt32(payloadSize), at: offset)
        offset = ret.addBytes(checksum, at: offset)
        ret.addData(payload, at: offset)
        return ret
    }
}
