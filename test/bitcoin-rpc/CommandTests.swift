import Testing
import BitcoinCrypto
import Foundation
import BitcoinBlockchain
import BitcoinTransport
import JSONRPC
import BitcoinRPC

struct CommandTests {

    @Test("Blockchain Info")
    func blockchainInfo() async throws {
        // TODO: Enable tmp storage to get valid sizeOnDisk readings.

        let satoshiChain = BlockchainService(params: .swiftTesting)
        await satoshiChain.start()
        let pubkey = try #require(PubKey(compressed: [0x02, 0x9a, 0x38, 0x65, 0xb2, 0x48, 0x8e, 0x2f, 0xee, 0x75, 0x33, 0x6d, 0x10, 0x48, 0xc1, 0xd0, 0x79, 0x5a, 0x08, 0x83, 0x68, 0xa0, 0xca, 0xa4, 0xad, 0xc0, 0x76, 0x42, 0x5c, 0x90, 0x22, 0x7b, 0xc3]))

        let satoshi = NodeService(blockchain: satoshiChain, config: .init(feeFilterRate: 2))

        let output1 = await GetBlockchainInfoRPC().run(blockchain: satoshiChain)
        #expect(output1.chain == "swift-testing")
        #expect(output1.blocks == 0)
        #expect(output1.headers == 0)
        #expect(output1.bestBlockHash == "0f9188f13cb7b2c71f2a335e3a4fc328bf5beb436012afca590b1a11466e2206")
        #expect(output1.difficulty == "4.656542373906925e-10") // If it was a Double it would be `4.6565423739069247e-10`
        #expect(output1.time == 1296688602)
        #expect(output1.medianTime == 1296688602)
        #expect(output1.verificationProgress == 1)
        #expect(output1.initialBlockDownload)
        #expect(output1.chainwork == "0000000000000000000000000000000000000000000000000000000000000002")
        #expect(output1.sizeOnDisk == 0) // 293

        // Fixing date for to get a stable block ID for comparison
        let fixedTime = 1739295700
        await satoshiChain.generateTo(pubkey, blockTime: Date(timeIntervalSince1970: TimeInterval(fixedTime)))

        let output2 = await GetBlockchainInfoRPC().run(blockchain: satoshiChain)
        #expect(output2.chain == "swift-testing")
        #expect(output2.blocks == 1)
        #expect(output2.headers == 1)
        #expect(output2.bestBlockHash == "781576e309f1153343397e5acdd0f9be7bcc361db98133e0071f762e22142881")
        #expect(output2.difficulty == "4.656542373906925e-10") // If it was a Double it would be `4.6565423739069247e-10`
        #expect(output2.time == fixedTime)
        #expect(output2.medianTime == fixedTime)
        #expect(output2.verificationProgress == 1)
        #expect(output2.initialBlockDownload)
        #expect(output2.chainwork == "0000000000000000000000000000000000000000000000000000000000000004")
        #expect(output2.sizeOnDisk == 0) // Requires data dir, 552 (Swift Bitcoin, no undo data) or 593 (Bitcoin Core, with undo data)

        // Unfixing date for to get a valid IDB reading
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .gmt
        let nowSeconds = calendar.date(bySetting: .nanosecond, value: 0, of: Date.now)!

        await satoshiChain.generateTo(pubkey, blockTime: nowSeconds)

        let output3 = await GetBlockchainInfoRPC().run(blockchain: satoshiChain)
        #expect(output3.chain == "swift-testing")
        #expect(output3.blocks == 2)
        #expect(output3.headers == 2)
        #expect(output3.difficulty == "4.656542373906925e-10") // If it was a Double it would be `4.6565423739069247e-10`
        #expect(output3.time == Int(nowSeconds.timeIntervalSince1970))
        #expect(output3.medianTime == fixedTime)
        #expect(output3.verificationProgress == 1)
        #expect(!output3.initialBlockDownload)
        #expect(output3.chainwork == "0000000000000000000000000000000000000000000000000000000000000006")
        #expect(output3.sizeOnDisk == 0) // Requires data dir, 552 (Swift Bitcoin, no undo data) or 593 (Bitcoin Core, with undo data)
        await satoshi.stop()
        await satoshiChain.stop()
    }
}
