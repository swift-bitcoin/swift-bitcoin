import XCTest
@testable import Bitcoin  // @testable for Script.data
import BitcoinCrypto

final class BlockTests: XCTestCase {

    let service = BitcoinService()

    /// Tests the creation of the genesis block and genesis coinbase transaction.
    func testGenesisBlock() async throws {
        let expectedGenesisTxHash = "4a5e1e4baab89f3a32518a88c31bc87f618f76673e2cc77ab2127b7afdeda33b"
        let expectedBlockData = "0100000000000000000000000000000000000000000000000000000000000000000000003ba3edfd7a7b12b27ac72c3e67768f617fc81bc3888a51323a9fb8aa4b1e5e4adae5494dffff7f20020000000101000000010000000000000000000000000000000000000000000000000000000000000000ffffffff4d04ffff001d0104455468652054696d65732030332f4a616e2f32303039204368616e63656c6c6f72206f6e206272696e6b206f66207365636f6e64206261696c6f757420666f722062616e6b73ffffffff0100f2052a01000000434104678afdb0fe5548271967f1a67130b7105cd6a828e03909a67962e0ea1f61deb649f6bc3f4cef38c4f35504e51ec112de5c384df7ba0b8d578a4c702b6bf11d5fac00000000"
        let expectedBlockHash = "0f9188f13cb7b2c71f2a335e3a4fc328bf5beb436012afca590b1a11466e2206"

        await service.createGenesisBlock()

        let genesisBlock = await service.genesisBlock
        let genesisTx = genesisBlock.transactions[0]

        XCTAssertEqual(genesisTx.identifier.hex, expectedGenesisTxHash)

        let genesisBlockData = genesisBlock.data
        XCTAssertEqual(genesisBlockData.hex, expectedBlockData)

        guard let genesisBlockRedeserialized = TransactionBlock(genesisBlockData) else {
            XCTFail(); return
        }
        XCTAssertEqual(genesisBlockRedeserialized, genesisBlock)
        XCTAssertEqual(genesisBlock.identifier.hex, expectedBlockHash)
    }

    /// Tests one empty block right after the genesis block at height 1. Includes checks for the coinbase transaction.
    func testBlock1() async throws {
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

        let expectedBlockData = Data(hex: "0000002006226e46111a0b59caaf126043eb5bbf28c34f3a5e332a1fc7b2b73cf188910fbec765a1f75eb654fb485e81df36df6d7edfbb81a8e448bdb9dc30cb9b2d757259919e65ffff7f200200000001020000000001010000000000000000000000000000000000000000000000000000000000000000ffffffff025100ffffffff0200f2052a010000001976a91425337bc59613aa8717459c5f7e6bf29479ddd0ed88ac0000000000000000266a24aa21a9ede2f61c3f71d1defd3fa999dfa36953755c690689799962b48bebd836974e8cf90120000000000000000000000000000000000000000000000000000000000000000000000000")!
        guard let expectedBlock = TransactionBlock(expectedBlockData) else { XCTFail(); return }

        // Quick round trip check.
        XCTAssertEqual(expectedBlock.data, expectedBlockData)

        let expectedBlockHash = "647024ae6cf6ba659ba4c5c5aeeafe5877926f1da798e4e80ed2b79058cbf7be"

        let expectedCoinbaseTxData = Data(hex: "020000000001010000000000000000000000000000000000000000000000000000000000000000ffffffff025100ffffffff0200f2052a010000001976a91425337bc59613aa8717459c5f7e6bf29479ddd0ed88ac0000000000000000266a24aa21a9ede2f61c3f71d1defd3fa999dfa36953755c690689799962b48bebd836974e8cf90120000000000000000000000000000000000000000000000000000000000000000000000000")!
        guard let expectedCoinbaseTx = BitcoinTransaction(expectedCoinbaseTxData) else { XCTFail(); return }
        XCTAssertEqual(expectedCoinbaseTx.data, expectedCoinbaseTxData)

        await service.createGenesisBlock()

        await service.generateTo("miueyHbQ33FDcjCYZpVJdC7VBbaVQzAUg5", blockTime: .init(timeIntervalSince1970: 1704890713))

        let block = await service.blockchain[1]
        let coinbaseTx = block.transactions[0]
        let expectedWitnessCommitmentHash = "6a24aa21a9ede2f61c3f71d1defd3fa999dfa36953755c690689799962b48bebd836974e8cf9"

        XCTAssertEqual(coinbaseTx.outputs[1].script.data.hex, expectedWitnessCommitmentHash)
        XCTAssertEqual(coinbaseTx, expectedCoinbaseTx)
        XCTAssertEqual(coinbaseTx.data, expectedCoinbaseTxData)
        XCTAssertEqual(block, expectedBlock)
        XCTAssertEqual(block.data, expectedBlockData)
        XCTAssertEqual(block.identifier.hex, expectedBlockHash)

        // Test block message
        let blockMessage = BlockMessage(block: block)
        let blockMessageData = blockMessage.data
        guard let blockMessageRoundtrip = BlockMessage(blockMessageData) else {
            XCTFail(); return
        }
        XCTAssertEqual(blockMessageRoundtrip.data, blockMessageData)

        // Test block message regtest
        let blockMessageRegtest = BlockMessage(block: block, network: .regtest)
        let blockMessageRegtestData = blockMessageRegtest.data
        guard let blockMessageRegtestRoundtrip = BlockMessage(blockMessageRegtestData) else {
            XCTFail(); return
        }
        XCTAssertEqual(blockMessageRegtestRoundtrip.data, blockMessageRegtestData)
    }

    func testBlockDateNanoseconds() throws {
        let emptyBlock = TransactionBlock(
            header: .init(
                previous: Data(repeating: 0, count: 32),
                merkleRoot:  Data(repeating: 0, count: 32),
                target: 0x207fffff,
                nonce: 2
            ),
            transactions: [])
        guard let blockRoundTrip = TransactionBlock(emptyBlock.data) else {
            XCTFail(); return
        }
        XCTAssertEqual(blockRoundTrip, emptyBlock)
    }
}
