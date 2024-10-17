import Testing
import BitcoinCrypto
import Foundation
import BitcoinBlockchain
import BitcoinTransport
@testable import BitcoinRPC

final class CommandTests {

    var satoshiChain = BitcoinService?.none
    var satoshi = NodeService?.none

    init() async throws {
        let satoshiChain = BitcoinService()
        let publicKey = try #require(PublicKey(compressed: [0x03, 0x5a, 0xc9, 0xd1, 0x48, 0x78, 0x68, 0xec, 0xa6, 0x4e, 0x93, 0x2a, 0x06, 0xee, 0x8d, 0x6d, 0x2e, 0x89, 0xd9, 0x86, 0x59, 0xdb, 0x7f, 0x24, 0x74, 0x10, 0xd3, 0xe7, 0x9f, 0x88, 0xf8, 0xd0, 0x05])) // Testnet p2pkh address  miueyHbQ33FDcjCYZpVJdC7VBbaVQzAUg5
        await satoshiChain.generateTo(publicKey)

        self.satoshiChain = satoshiChain
        let satoshi = NodeService(bitcoinService: satoshiChain, feeFilterRate: 2)
        self.satoshi = satoshi
    }

    deinit {
        if let satoshi, let satoshiChain {
            Task {
                await satoshi.stop()
                await satoshiChain.shutdown()
            }
        }
    }

    @Test("Blockchain Info")
    func blockchainInfo() async throws {
        guard let satoshiChain else { preconditionFailure() }
        let command = GetBlockchainInfoCommand(bitcoinService: satoshiChain)
        let result = await command.run(.init(id: "", method: "get-blockchain-info", params: .none))
        let _ = try #require(result.result)
    }
}
