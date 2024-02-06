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

    func testDifficulty() async throws {
        let difficultyBits = 0x207fffff
        let powLimitBE = Data(hex: "7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff")! // Regtest
        let powLimitLE = Data(powLimitBE.reversed())
        let powLimitUInt256 = Arithmetic256.fromData(powLimitLE)
        XCTAssertEqual(Arithmetic256.toData(powLimitUInt256), powLimitLE)
        let powLimitCompact = Arithmetic256.toCompact(powLimitUInt256)
        XCTAssertEqual(powLimitCompact, difficultyBits)

        var neg: Bool = true
        var over: Bool = true
        let powLimitUInt256_ = Arithmetic256.fromCompact(powLimitCompact, negative: &neg, overflow: &over)
        if Arithmetic256.isZero(powLimitUInt256_) || neg || over {
            XCTFail(); return
        }
        let powLimitLE_ = Arithmetic256.toData(powLimitUInt256_)
        XCTAssertEqual(powLimitLE_.reversed().hex, "7fffff0000000000000000000000000000000000000000000000000000000000")
    }

    func testDifficultyAdjustment() async throws {
        let service = BitcoinService(consensusParameters: .init(
            powLimit: Data(hex: "7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff")!,
            powTargetTimespan: 1 * 1 * 10 * 60, // 12 minutes
            powTargetSpacing: 2 * 60, // 2 minutes
            powAllowMinDifficultyBlocks: true,
            powNoRetargeting: false
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
                0x207fffff // 0x7fffff0000000000000000000000000000000000000000000000000000000000 (Arithmetic256.toData(Arithmetic256.fromCompact(block.header.target)).reversed().hex)
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
}
