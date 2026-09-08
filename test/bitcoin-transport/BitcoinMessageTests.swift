import Testing
import Foundation
import BinaryParsing
import BitcoinBase
import BitcoinBlockchain
@testable import BitcoinTransport

struct BitcoinMessageTests {

    @Test("Malformed message")
    func malformed() throws {
        let data = Data([0xfa, 0xbf, 0xb5, 0xda, 0x77, 0x74, 0x78, 0x69, 0x64, 0x72, 0x65, 0x6c, 0x61, 0x79, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x5d, 0xf6, 0xe0, 0xe2])
        let parsed = NetworkMessage(data)
        #expect(parsed != nil)
    }

    @Test("Headers roundtrip")
    func headersRoundtrip() throws {
        let header = Block(previous: .init(count: 32), merkleRoot: .init(count: 32), time: .now, target: 0)
        let header1 = Block(previous: .init(count: 32), merkleRoot: .init(count: 32), time: .now, target: 0, nonce: 1)
        let header2 = Block(previous: .init(count: 32), merkleRoot: .init(count: 32), time: .now, target: 0, nonce: 2)
        let headers = HeadersMessage(items: [header, header1, header2])
        let headersData = headers.data
        let headers2 = HeadersMessage(headersData)
        #expect(headers == headers2)
    }

    @Test("Compact block")
    func compactBlock() throws {
        // Check 6-byte integer conversion first
        let val = UInt64(0x0000ffffffffffff)
        let data = Data(capacity: MemoryLayout<UInt64>.size) { out in
            out.append(val, as: UInt64.self, .littleEndian)
        }
        // Keep only 6 less significant bytes.
        var ret = Data(repeating: 0xff, count: 8)
        let _ = ret.addData(data.prefix(6))
        let val1 = try! (ret.prefix(6) + Data(count: 2)).withParserSpan { input in
            try UInt64(parsingLittleEndian: &input)
        }
        #expect(val == val1)

        let tx = Transaction(ins: [.init(outpoint: .coinbase)], outs: [.init(value: 100)])
        let header = Block(previous: .init(count: 32), merkleRoot: .init(count: 32), target: 0)
        let message = CompactBlockMessage(header: header, nonce: 0, txIDs: [val], txs: [.init(index: 0, tx: tx)])
        let messageData = message.data
        let message2 = try #require(CompactBlockMessage(messageData))
        #expect(message == message2)
    }

    /// BIP339 WTX inventory item type 5
    @Test func witnessTxInventory() throws {
        let messagePayload = Data([0x02, 0x05, 0x00, 0x00, 0x00, 0x47, 0xf0, 0x48, 0xa4, 0x3a, 0xc1, 0xfe, 0x99, 0x58, 0xb7, 0x67, 0x15, 0xd2, 0xe0, 0xaa, 0xee, 0x16, 0x1d, 0xba, 0x86, 0x6e, 0x27, 0x35, 0x1a, 0x66, 0xed, 0xcc, 0x99, 0x37, 0xb3, 0x53, 0xc5, 0x05, 0x00, 0x00, 0x00, 0xb2, 0x4a, 0x69, 0x18, 0xc9, 0x98, 0x85, 0x81, 0x43, 0x8d, 0x55, 0xb7, 0x29, 0xa1, 0xf7, 0x1f, 0x97, 0x6e, 0xf5, 0x16, 0xca, 0x17, 0x32, 0x89, 0xb2, 0xeb, 0x01, 0x33, 0x23, 0xda, 0xd7, 0xfd]) // Testnet 4 transaction
        let inv = InventoryMessage(messagePayload)
        #expect(inv != nil)
    }
}
