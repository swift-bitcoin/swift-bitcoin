import Testing
import Foundation
import BitcoinBase
import BitcoinBlockchain
@testable import BitcoinTransport

struct BitcoinMessageTests {

    @Test("Malformed message")
    func malformed() throws {
        let data = Data([0xfa, 0xbf, 0xb5, 0xda, 0x77, 0x74, 0x78, 0x69, 0x64, 0x72, 0x65, 0x6c, 0x61, 0x79, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x5d, 0xf6, 0xe0, 0xe2])
        let parsed = BitcoinMessage(data)
        #expect(parsed != nil)
    }

    @Test("Headers roundtrip")
    func headersRoundtrip() throws {
        let header = TxBlock(previous: .init(count: 32), merkleRoot: .init(count: 32), time: .now, target: 0)
        let header1 = TxBlock(previous: .init(count: 32), merkleRoot: .init(count: 32), time: .now, target: 0, nonce: 1)
        let header2 = TxBlock(previous: .init(count: 32), merkleRoot: .init(count: 32), time: .now, target: 0, nonce: 2)
        let headers = HeadersMessage(items: [header, header1, header2])
        let headersData = headers.data
        let headers2 = HeadersMessage(headersData)
        #expect(headers == headers2)
    }

    @Test("Compact block")
    func compactBlock() throws {
        // Check 6-byte integer conversion first
        let val = UInt64(0x0000ffffffffffff)
        let data = withUnsafeBytes(of: val) {
            Data($0)
        }
        // Keep only 6 less significant bytes.
        var ret = Data(repeating: 0xff, count: 8)
        let _ = ret.addData(data.prefix(6))
        let val1 = (ret.prefix(6) + Data(count: 2)).withUnsafeBytes {
            $0.loadUnaligned(as: UInt64.self)
        }
        #expect(val == val1)

        let tx = BitcoinTx(ins: [.init(outpoint: .coinbase)], outs: [.init(value: 100)])
        let header = TxBlock(previous: .init(count: 32), merkleRoot: .init(count: 32), target: 0)
        let message = CompactBlockMessage(header: header, nonce: 0, txIDs: [val], txs: [.init(index: 0, tx: tx)])
        let messageData = message.data
        let message2 = try #require(CompactBlockMessage(messageData))
        #expect(message == message2)
    }
}
