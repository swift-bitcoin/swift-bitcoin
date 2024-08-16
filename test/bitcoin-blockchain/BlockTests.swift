import Testing
import Foundation
@testable import BitcoinBlockchain  // @testable for Script.data
import BitcoinCrypto
import BitcoinBase

struct BlockTests {

    let service = BitcoinService()

    /// Tests the creation of the genesis block and genesis coinbase transaction.
    @Test("Genesis block")
    func genesisBlock() async throws {
        let expectedGenesisTxHash = "4a5e1e4baab89f3a32518a88c31bc87f618f76673e2cc77ab2127b7afdeda33b"
        let expectedBlockData = "0100000000000000000000000000000000000000000000000000000000000000000000003ba3edfd7a7b12b27ac72c3e67768f617fc81bc3888a51323a9fb8aa4b1e5e4adae5494dffff7f20020000000101000000010000000000000000000000000000000000000000000000000000000000000000ffffffff4d04ffff001d0104455468652054696d65732030332f4a616e2f32303039204368616e63656c6c6f72206f6e206272696e6b206f66207365636f6e64206261696c6f757420666f722062616e6b73ffffffff0100f2052a01000000434104678afdb0fe5548271967f1a67130b7105cd6a828e03909a67962e0ea1f61deb649f6bc3f4cef38c4f35504e51ec112de5c384df7ba0b8d578a4c702b6bf11d5fac00000000"
        let expectedBlockHash = "0f9188f13cb7b2c71f2a335e3a4fc328bf5beb436012afca590b1a11466e2206"

        await service.createGenesisBlock()

        let genesisBlock = await service.genesisBlock
        let genesisTx = genesisBlock.transactions[0]

        #expect(genesisTx.identifier.hex == expectedGenesisTxHash)

        let genesisBlockData = genesisBlock.data
        #expect(genesisBlockData.hex == expectedBlockData)

        let genesisBlockRedeserialized = try #require(TransactionBlock(genesisBlockData))
        #expect(genesisBlockRedeserialized == genesisBlock)
        #expect(genesisBlock.identifier.hex == expectedBlockHash)

        // Short transaction ID
        // TODO: The following value is taken from the function's output so nothing is being verified until replaced with a known-to-be valid ID.
        let expectedShortTransactionIdentifier = 0x00005b073a0c72eb
        #expect(genesisBlock.makeShortTransactionIdentifier(for: 0, nonce: 0) == expectedShortTransactionIdentifier)
    }

    /// Tests one empty block right after the genesis block at height 1. Includes checks for the coinbase transaction.
    @Test("Block 1")
    func block1() async throws {
        // TODO: Incorporate coinbase transaction and block generation logic into `Bitcoin.TransactionBlock`.

        // The following was performed on a new regtest with only the genesis block.
        //
        // secretKey = `bcutil ec-new`
        // 45851ee2662f0c36f4fd2a7d53a08f7b06c7abfd61953c5216cc397c4f2cae8c
        //
        // publicKEy = `bcutil ec-to-public $secretKey`
        // 035ac9d1487868eca64e932a06ee8d6d2e89d98659db7f247410d3e79f88f8d005
        //
        // address = `bcutil ec-to-address -n test $publicKey`
        // miueyHbQ33FDcjCYZpVJdC7VBbaVQzAUg5
        //
        // blockHash = `bitcoin-cli generatetoaddress 1 $address`
        // [ 647024ae6cf6ba659ba4c5c5aeeafe5877926f1da798e4e80ed2b79058cbf7be ]
        //
        // bitcoin-cli   $blockHash
        // {
        //   "height": 1,
        //   "versionHex": "20000000",
        //   "merkleroot": "72752d9bcb30dcb9bd48e4a881bbdf7e6ddf36df815e48fb54b65ef7a165c7be",
        //   "time": 1704890713,
        //   "mediantime": 1704890713,
        //   "nonce": 2,
        //   "bits": "207fffff",
        //   "difficulty": 4.656542373906925e-10,
        //   "chainwork": "0000000000000000000000000000000000000000000000000000000000000004",
        //   "previousblockhash": "0f9188f13cb7b2c71f2a335e3a4fc328bf5beb436012afca590b1a11466e2206",
        //   "strippedsize": 215,
        //   "size": 251,
        //   "weight": 896,
        //   "tx": [
        //     "72752d9bcb30dcb9bd48e4a881bbdf7e6ddf36df815e48fb54b65ef7a165c7be"
        //   ]
        // }
        //
        // blockData = `bitcoin-cli getblock $blockHash 0`
        // 0000002006226e46111a0b59caaf126043eb5bbf28c34f3a5e332a1fc7b2b73cf188910fbec765a1f75eb654fb485e81df36df6d7edfbb81a8e448bdb9dc30cb9b2d757259919e65ffff7f200200000001020000000001010000000000000000000000000000000000000000000000000000000000000000ffffffff025100ffffffff0200f2052a010000001976a91425337bc59613aa8717459c5f7e6bf29479ddd0ed88ac0000000000000000266a24aa21a9ede2f61c3f71d1defd3fa999dfa36953755c690689799962b48bebd836974e8cf90120000000000000000000000000000000000000000000000000000000000000000000000000
        //
        // txData = `bitcoin-cli getrawtransaction 72752d9bcb30dcb9bd48e4a881bbdf7e6ddf36df815e48fb54b65ef7a165c7be`
        // 020000000001010000000000000000000000000000000000000000000000000000000000000000ffffffff025100ffffffff0200f2052a010000001976a91425337bc59613aa8717459c5f7e6bf29479ddd0ed88ac0000000000000000266a24aa21a9ede2f61c3f71d1defd3fa999dfa36953755c690689799962b48bebd836974e8cf90120000000000000000000000000000000000000000000000000000000000000000000000000
        // bitcoin-cli decoderawtransaction $txData
        // {
        //   "hash/witnessID": "3eb9f2b49d5eb916d2a00f01016600257f2a639f7e11fbe442014d6ceabd8878",
        //   "version": 2,
        //   "size": 170,
        //   "vsize": 143,
        //   "weight": 572,
        //   "locktime": 0,
        //   "vin": [
        //     {
        //       "coinbase": "5100",
        //       "txinwitness": [
        //         "0000000000000000000000000000000000000000000000000000000000000000"
        //       ],
        //       "sequence": 4294967295
        //     }
        //   ],
        //   "vout": [
        //     {
        //       "value": 50.00000000,
        //       "n": 0,
        //       "scriptPubKey": {
        //         "asm": "OP_DUP OP_HASH160 25337bc59613aa8717459c5f7e6bf29479ddd0ed OP_EQUALVERIFY OP_CHECKSIG",
        //         "hex": "76a91425337bc59613aa8717459c5f7e6bf29479ddd0ed88ac",
        //         "type": "pubkeyhash"
        //       }
        //     },
        //     {
        //       "value": 0.00000000,
        //       "n": 1,
        //       "scriptPubKey": {
        //         "asm": "OP_RETURN aa21a9ede2f61c3f71d1defd3fa999dfa36953755c690689799962b48bebd836974e8cf9"
        //         "hex": "6a24aa21a9ede2f61c3f71d1defd3fa999dfa36953755c690689799962b48bebd836974e8cf9",
        //         "type": "nulldata"
        //       }
        //     }
        //   ]
        // }

        let expectedBlockData = Data([0x00, 0x00, 0x00, 0x20, 0x06, 0x22, 0x6e, 0x46, 0x11, 0x1a, 0x0b, 0x59, 0xca, 0xaf, 0x12, 0x60, 0x43, 0xeb, 0x5b, 0xbf, 0x28, 0xc3, 0x4f, 0x3a, 0x5e, 0x33, 0x2a, 0x1f, 0xc7, 0xb2, 0xb7, 0x3c, 0xf1, 0x88, 0x91, 0x0f, 0xbe, 0xc7, 0x65, 0xa1, 0xf7, 0x5e, 0xb6, 0x54, 0xfb, 0x48, 0x5e, 0x81, 0xdf, 0x36, 0xdf, 0x6d, 0x7e, 0xdf, 0xbb, 0x81, 0xa8, 0xe4, 0x48, 0xbd, 0xb9, 0xdc, 0x30, 0xcb, 0x9b, 0x2d, 0x75, 0x72, 0x59, 0x91, 0x9e, 0x65, 0xff, 0xff, 0x7f, 0x20, 0x02, 0x00, 0x00, 0x00, 0x01, 0x02, 0x00, 0x00, 0x00, 0x00, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xff, 0xff, 0xff, 0xff, 0x02, 0x51, 0x00, 0xff, 0xff, 0xff, 0xff, 0x02, 0x00, 0xf2, 0x05, 0x2a, 0x01, 0x00, 0x00, 0x00, 0x19, 0x76, 0xa9, 0x14, 0x25, 0x33, 0x7b, 0xc5, 0x96, 0x13, 0xaa, 0x87, 0x17, 0x45, 0x9c, 0x5f, 0x7e, 0x6b, 0xf2, 0x94, 0x79, 0xdd, 0xd0, 0xed, 0x88, 0xac, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x26, 0x6a, 0x24, 0xaa, 0x21, 0xa9, 0xed, 0xe2, 0xf6, 0x1c, 0x3f, 0x71, 0xd1, 0xde, 0xfd, 0x3f, 0xa9, 0x99, 0xdf, 0xa3, 0x69, 0x53, 0x75, 0x5c, 0x69, 0x06, 0x89, 0x79, 0x99, 0x62, 0xb4, 0x8b, 0xeb, 0xd8, 0x36, 0x97, 0x4e, 0x8c, 0xf9, 0x01, 0x20, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        let expectedBlock = try #require(TransactionBlock(expectedBlockData))

        // Quick round trip check.
        #expect(expectedBlock.data == expectedBlockData)

        let expectedBlockHash = "647024ae6cf6ba659ba4c5c5aeeafe5877926f1da798e4e80ed2b79058cbf7be"

        let expectedCoinbaseTxData = Data([0x02, 0x00, 0x00, 0x00, 0x00, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xff, 0xff, 0xff, 0xff, 0x02, 0x51, 0x00, 0xff, 0xff, 0xff, 0xff, 0x02, 0x00, 0xf2, 0x05, 0x2a, 0x01, 0x00, 0x00, 0x00, 0x19, 0x76, 0xa9, 0x14, 0x25, 0x33, 0x7b, 0xc5, 0x96, 0x13, 0xaa, 0x87, 0x17, 0x45, 0x9c, 0x5f, 0x7e, 0x6b, 0xf2, 0x94, 0x79, 0xdd, 0xd0, 0xed, 0x88, 0xac, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x26, 0x6a, 0x24, 0xaa, 0x21, 0xa9, 0xed, 0xe2, 0xf6, 0x1c, 0x3f, 0x71, 0xd1, 0xde, 0xfd, 0x3f, 0xa9, 0x99, 0xdf, 0xa3, 0x69, 0x53, 0x75, 0x5c, 0x69, 0x06, 0x89, 0x79, 0x99, 0x62, 0xb4, 0x8b, 0xeb, 0xd8, 0x36, 0x97, 0x4e, 0x8c, 0xf9, 0x01, 0x20, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        let expectedCoinbaseTx = try #require(BitcoinTransaction(expectedCoinbaseTxData))
        #expect(expectedCoinbaseTx.data == expectedCoinbaseTxData)

        await service.createGenesisBlock()

        await service.generateTo("miueyHbQ33FDcjCYZpVJdC7VBbaVQzAUg5", blockTime: .init(timeIntervalSince1970: 1704890713))

        let block = await service.getBlock(1)
        let coinbaseTx = block.transactions[0]
        let expectedWitnessCommitmentHash = "6a24aa21a9ede2f61c3f71d1defd3fa999dfa36953755c690689799962b48bebd836974e8cf9"

        #expect(coinbaseTx.outputs[1].script.data.hex == expectedWitnessCommitmentHash)
        #expect(coinbaseTx == expectedCoinbaseTx)
        #expect(coinbaseTx.data == expectedCoinbaseTxData)
        #expect(block == expectedBlock)
        #expect(block.data == expectedBlockData)
        #expect(block.identifier.hex == expectedBlockHash)

        // Short transaction ID
        // TODO: The following value is taken from the function's output so nothing is being verified until replaced with a known-to-be valid ID.
        //let expectedShortTransactionIdentifier = Data([0x20, 0xb2, 0x36, 0x73, 0x7a, 0xcb])
        // let expectedShortTransactionIdentifier = 0x0000cb7a7336b220
        //XCTAssertEqual(block.makeShortTransactionIdentifier(for: 0, nonce: 0), expectedShortTransactionIdentifier)
    }

    @Test("Block date/time nanoseconds")
    func blockDateNanoseconds() throws {
        let emptyBlock = TransactionBlock(
            header: .init(
                previous: Data(repeating: 0, count: 32),
                merkleRoot:  Data(repeating: 0, count: 32),
                target: 0x207fffff,
                nonce: 2
            ),
            transactions: [])
        let blockRoundTrip = try #require(TransactionBlock(emptyBlock.data))
        #expect(blockRoundTrip == emptyBlock)
    }
}
