import XCTest
@testable import Bitcoin // @testable for signatureHash(), SigHashType
import BitcoinCrypto

final class BitcoinServiceTests: XCTestCase {

    /// Tests mining empty blocks, spending a coinbase transaction and mine again.
    func testMineAndSpend() async throws {
        let service = BitcoinService()
        await service.createGenesisBlock()
        for _ in 0 ..< 100 {
            await service.generateTo("miueyHbQ33FDcjCYZpVJdC7VBbaVQzAUg5")
        }

        // Create spending transaction
        let previousTransaction = await service.blockchain[1].transactions[0]
        let previousOutput = previousTransaction.outputs[0]
        let outpoint = previousTransaction.outpoint(for: 0)!
        let unsignedInput = TransationInput(outpoint: outpoint, sequence: .final)
        let unsignedTransaction = BitcoinTransaction(
            version: .v1,
            inputs: [unsignedInput],
            outputs: [
                .init(value: 49_98_000_000, script: .init([
                    .dup,
                    .hash160,
                    .pushBytes(Data(hex: "25337bc59613aa8717459c5f7e6bf29479ddd0ed")!),
                    .equalVerify,
                    .checkSig
                ]))
            ])

        // Sign the transaction
        let sigHash = unsignedTransaction.signatureHash(sighashType: .all, inputIndex: 0, previousOutput: previousOutput, scriptCode: previousOutput.script.data)
        let sig = signECDSA(message: sigHash, secretKey: Data(hex: "45851ee2662f0c36f4fd2a7d53a08f7b06c7abfd61953c5216cc397c4f2cae8c")!) + [SighashType.all.value]
        let signedInput = TransationInput(
            outpoint: unsignedInput.outpoint,
            sequence: unsignedInput.sequence,
            script: .init([
                .pushBytes(sig),
                .pushBytes(Data(hex: "035ac9d1487868eca64e932a06ee8d6d2e89d98659db7f247410d3e79f88f8d005")!)
            ]),
            witness: unsignedInput.witness)
        let signedTransaction = BitcoinTransaction(
            version: unsignedTransaction.version,
            locktime: unsignedTransaction.locktime,
            inputs: [signedInput],
            outputs: unsignedTransaction.outputs)
        XCTAssert(signedTransaction.verifyScript(previousOutputs: [previousOutput]))

        await service.addTransaction(signedTransaction)
        let mempoolBefore = await service.mempool.count
        XCTAssertEqual(mempoolBefore, 1)
        await service.generateTo("miueyHbQ33FDcjCYZpVJdC7VBbaVQzAUg5")
        let mempoolAfter = await service.mempool.count
        XCTAssertEqual(mempoolAfter, 0)
        let blocks = await service.blockchain.count
        XCTAssertEqual(blocks, 102)
        guard let lastBlock = await service.blockchain.last else {
            XCTFail(); return
        }
        XCTAssertEqual(lastBlock.transactions[1], signedTransaction)
        // createrawtransaction [{"txid":"hex","vout":n,"sequence":n},...] [{"address":amount,...},{"data":"hex"},...] ( locktime replaceable )
        // createrawtransaction '[{"txid":"72752d9bcb30dcb9bd48e4a881bbdf7e6ddf36df815e48fb54b65ef7a165c7be","vout":0}]' '[{"miueyHbQ33FDcjCYZpVJdC7VBbaVQzAUg5":49.99}]'
        // 0200000001bec765a1f75eb654fb485e81df36df6d7edfbb81a8e448bdb9dc30cb9b2d75720000000000fdffffff01c0aff629010000001976a91425337bc59613aa8717459c5f7e6bf29479ddd0ed88ac00000000

        //  bx ec-to-wif -v 239 45851ee2662f0c36f4fd2a7d53a08f7b06c7abfd61953c5216cc397c4f2cae8c
        // cPuqe8derNHnWuMtRfDUb8CGwuStiEeVAniZTHrmf9yTWyu7n481

        // signrawtransactionwithkey "hexstring" ["privatekey",...] ( [{"txid":"hex","vout":n,"scriptPubKey":"hex","redeemScript":"hex","witnessScript":"hex","amount":amount},...] "sighashtype" )

        // signrawtransactionwithkey "0200000001bec765a1f75eb654fb485e81df36df6d7edfbb81a8e448bdb9dc30cb9b2d75720000000000fdffffff01c0aff629010000001976a91425337bc59613aa8717459c5f7e6bf29479ddd0ed88ac00000000" '["cPuqe8derNHnWuMtRfDUb8CGwuStiEeVAniZTHrmf9yTWyu7n481"]'
        //  bc generatetoaddress 99 miuey…

    }
}
