import XCTest
@testable import Bitcoin // @testable for signatureHash(), SigHashType
import BitcoinCrypto

final class BitcoinServiceTests: XCTestCase {

    /// Tests mining empty blocks, spending a coinbase transaction and mine again.
    func testMineAndSpend() async throws {

        // Generate a secret key, corresponding public key, hash and address.
        let secretKey = Wallet.createSecretKey() as Data
        let publicKey = Wallet.getPublicKey(secretKey: secretKey)
        let publicKeyHash = hash160(publicKey)
        let address = try Wallet.getAddress(publicKey: publicKey, sigVersion: .base, network: .regtest)

        // Instantiate a fresh Bitcoin service (regtest).
        let service = BitcoinService()

        // Create the genesis block.
        await service.createGenesisBlock()

        // Mine 100 blocks so block 1's coinbase output reaches maturity.
        for _ in 0 ..< 100 {
            await service.generateTo(address)
        }

        // Grab block 1's coinbase transaction and output.
        let previousTransaction = await service.blockchain[1].transactions[0]
        let previousOutput = previousTransaction.outputs[0]
        let outpoint = previousTransaction.outpoint(for: 0)!

        // Create a new transaction spending from the previous transaction's outpoint.
        let unsignedInput = TransactionInput(outpoint: outpoint, sequence: .final)

        // Specify the transaction's output. We'll leave 1000 sats on the table to tip miners. We'll re-use the origin address for simplicity.
        let unsignedTransaction = BitcoinTransaction(
            inputs: [unsignedInput],
            outputs: [
                .init(value: 49_99_999_000, script: .init([
                    .dup,
                    .hash160,
                    .pushBytes(publicKeyHash),
                    .equalVerify,
                    .checkSig
                ]))
            ])

        // Sign the transaction by first calculating the signature hash.
        let sigHash = unsignedTransaction.signatureHash(sighashType: .all, inputIndex: 0, previousOutput: previousOutput, scriptCode: previousOutput.script.data)

        // Obtain the signature using our secret key and append the signature hash type.
        let sig = signECDSA(message: sigHash, secretKey: secretKey) + [SighashType.all.value]

        // Sign our input by including the signature and public key.
        let signedInput = TransactionInput(
            outpoint: unsignedInput.outpoint,
            sequence: unsignedInput.sequence,
            script: .init([
                .pushBytes(sig),
                .pushBytes(publicKey)
            ]),
            witness: unsignedInput.witness)

        // Put the signed input back into the transaction.
        let signedTransaction = BitcoinTransaction(
            version: unsignedTransaction.version,
            locktime: unsignedTransaction.locktime,
            inputs: [signedInput],
            outputs: unsignedTransaction.outputs)

        // Make sure the transaction was signed correctly by verifying the scripts.
        XCTAssert(signedTransaction.verifyScript(previousOutputs: [previousOutput]))

        // Submit the signed transaction to the mempool.
        await service.addTransaction(signedTransaction)
        let mempoolBefore = await service.mempool.count
        XCTAssertEqual(mempoolBefore, 1)

        // Let's mine another block to confirm our transaction.
        await service.generateTo(address)
        let mempoolAfter = await service.mempool.count

        // Verify the mempool is empty once again.
        XCTAssertEqual(mempoolAfter, 0)
        let blocks = await service.blockchain.count
        XCTAssertEqual(blocks, 102)
        guard let lastBlock = await service.blockchain.last else {
            XCTFail(); return
        }
        // Verify our transaction was confirmed in a block.
        XCTAssertEqual(lastBlock.transactions[1], signedTransaction)
    }

    func testDifficultyTarget() async throws {
        let difficultyBits = 0x207fffff
        let powLimitBE = Data([0x7f, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]) // Regtest
        let powLimitLE = Data(powLimitBE.reversed())
        let powLimitTarget = DifficultyTarget(powLimitLE)
        XCTAssertEqual(powLimitTarget.data, powLimitLE)
        let powLimitCompact = powLimitTarget.toCompact()
        XCTAssertEqual(powLimitCompact, difficultyBits)

        var neg: Bool = true
        var over: Bool = true
        let powLimitTarget_ = DifficultyTarget(compact: powLimitCompact, negative: &neg, overflow: &over)
        if powLimitTarget_.isZero || neg || over {
            XCTFail(); return
        }
        let powLimitLE_ = powLimitTarget_.data
        XCTAssertEqual(powLimitLE_.reversed().hex, "7fffff0000000000000000000000000000000000000000000000000000000000")
    }

    func testDifficultyAdjustment() async throws {
        let service = BitcoinService(consensusParams: .init(
            powLimit: Data([0x7f, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]),
            powTargetTimespan: 1 * 1 * 10 * 60, // 12 minutes
            powTargetSpacing: 2 * 60, // 2 minutes
            powAllowMinDifficultyBlocks: true,
            powNoRetargeting: false,
            genesisBlockTime: 1296688602,
            genesisBlockNonce: 2,
            genesisBlockTarget: 0x207fffff
        ))
        await service.createGenesisBlock()
        let genesisBlock = await service.genesisBlock

        XCTAssertEqual(genesisBlock.header.target, 0x207fffff)
        let genesisDate = genesisBlock.header.time
        var date = genesisDate
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .init(secondsFromGMT: 0)! // .gmt not available on linux

        for i in 1...15 {
            let minutes = if i < 5 { 4 } else if i < 10 { 2 } else { 4 }
            date = calendar.date(byAdding: .minute, value: minutes, to: date)!
            await service.generateTo("miueyHbQ33FDcjCYZpVJdC7VBbaVQzAUg5", blockTime: date)
            let block = await service.blockchain.last!
            let expectedTarget = if (1...4).contains(i) {
                0x207fffff // 0x7fffff0000000000000000000000000000000000000000000000000000000000 DifficultyTarget(compact: block.header.target).data.reversed().hex
            } else if (5...9).contains(i) {
                0x1f6d386d // 0x006d386d00000000000000000000000000000000000000000000000000000000
            } else if (10...14).contains(i) {
                0x1f576057 // 0x0057605700000000000000000000000000000000000000000000000000000000
            } else {
                0x1f1e9351 // 0x001e935100000000000000000000000000000000000000000000000000000000
            }
            XCTAssertEqual(block.header.target, expectedTarget)
        }
    }

    func testDifficulty() async throws {
        let cases = [
            // very_low_target
            (0x1f111111, 0.000001),
            // low_target
            (0x1ef88f6f, 0.000016),
            // mid_target
            (0x1df88f6f, 0.004023),
            // high_target
            (0x1cf88f6f, 1.029916),
            // very_high_target
            (0x12345678, 5913134931067755359633408.0)
        ]
        for (compact, expected) in cases {
            var negative = true
            var overflow = true
            let target = DifficultyTarget(compact: compact, negative: &negative, overflow: &overflow)
            XCTAssertFalse(target.isZero)
            XCTAssertFalse(overflow)
            XCTAssertEqual(target.toCompact(negative: negative), compact)
            XCTAssertEqual(DifficultyTarget.getDifficulty(compact), expected, accuracy: 0.00001)
        }
    }
}
