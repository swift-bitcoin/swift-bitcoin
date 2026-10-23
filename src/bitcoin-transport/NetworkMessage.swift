import Foundation
import BinaryParsing
import BitcoinCrypto
import BitcoinBlockchain

/// Any message sent or received by nodes on the peer-to-peer network.
public struct NetworkMessage: Equatable, Sendable {

    public init(_ command: MessageCommand, payload: Data = .init(), magicBytes: Int = NodeNetwork.regtest.magicBytes) {
        // TODO: - Remove the detault regtest magic bytes (or make mainnet the default)

        self.magicBytes = magicBytes
        self.command = command
        let payloadHash = Data(Hash256.hash(data: payload))
        self.checksum = payloadHash.withParserSpan { input in
            try! UInt32(parsingLittleEndian: &input)
        }
        self.payload = payload
    }

    /// Message start sequence (magic bytes) for the network.
    public let magicBytes: Int

    /// The message's command which also determines the type of payload – if any – that the message will carry.
    public let command: MessageCommand

    public let checksum: UInt32
    public let payload: Data

    public var isChecksumOk: Bool {
        let hash = Data(Hash256.hash(data: payload))
        let realChecksum = hash.withParserSpan { input in
            try! UInt32(parsingLittleEndian: &input)
        }
        return checksum == realChecksum
    }

    public static let baseSize = 24
    public static let payloadSizeStartIndex = 16
    public static let payloadSizeEndIndex = 20
}

extension NetworkMessage: BinaryCodable {

    public init(parsing input: inout ParserSpan, format: Never?) throws {
        magicBytes = Int(try UInt32(parsingLittleEndian: &input))
        command = try MessageCommand(parsing: &input)
        let payloadSize = Int(try UInt32(parsingLittleEndian: &input))
        checksum = try UInt32(parsingLittleEndian: &input)
        payload = Data(try [UInt8](parsing: &input, byteCount: payloadSize))
    }

    public func countBytes(into counter: inout BinarySizeCounter, format: Never?) {
        counter.count(UInt32.self)
        counter.count(command)
        counter.count(UInt32.self)
        counter.count(UInt32.self)
        counter.countSize(payload.count)
    }

    public func encode(into out: inout OutputRawSpan, format: Never?) throws {
        out.append(UInt32(magicBytes), as: UInt32.self, .littleEndian)
        try command.encode(into: &out)
        out.append(UInt32(payload.count), as: UInt32.self, .littleEndian)
        out.append(checksum, as: UInt32.self, .littleEndian)
        out.append(contentsOf: payload)
    }
}
