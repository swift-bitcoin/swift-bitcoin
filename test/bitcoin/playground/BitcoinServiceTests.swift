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
    }

    func testDifficultyTarget() async throws {
        let difficultyBits = 0x207fffff
        let powLimitBE = Data(hex: "7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff")! // Regtest
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
        let service = BitcoinService(consensusParameters: .init(
            powLimit: Data(hex: "7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff")!,
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
