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
                    .pushBytes(Data([0x25, 0x33, 0x7b, 0xc5, 0x96, 0x13, 0xaa, 0x87, 0x17, 0x45, 0x9c, 0x5f, 0x7e, 0x6b, 0xf2, 0x94, 0x79, 0xdd, 0xd0, 0xed])),
                    .equalVerify,
                    .checkSig
                ]))
            ])

        // Sign the transaction
        let sigHash = unsignedTransaction.signatureHash(sighashType: .all, inputIndex: 0, previousOutput: previousOutput, scriptCode: previousOutput.script.data)
        let sig = signECDSA(message: sigHash, secretKey: Data([0x45, 0x85, 0x1e, 0xe2, 0x66, 0x2f, 0x0c, 0x36, 0xf4, 0xfd, 0x2a, 0x7d, 0x53, 0xa0, 0x8f, 0x7b, 0x06, 0xc7, 0xab, 0xfd, 0x61, 0x95, 0x3c, 0x52, 0x16, 0xcc, 0x39, 0x7c, 0x4f, 0x2c, 0xae, 0x8c])) + [SighashType.all.value]
        let signedInput = TransationInput(
            outpoint: unsignedInput.outpoint,
            sequence: unsignedInput.sequence,
            script: .init([
                .pushBytes(sig),
                .pushBytes(Data([0x03, 0x5a, 0xc9, 0xd1, 0x48, 0x78, 0x68, 0xec, 0xa6, 0x4e, 0x93, 0x2a, 0x06, 0xee, 0x8d, 0x6d, 0x2e, 0x89, 0xd9, 0x86, 0x59, 0xdb, 0x7f, 0x24, 0x74, 0x10, 0xd3, 0xe7, 0x9f, 0x88, 0xf8, 0xd0, 0x05]))
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
