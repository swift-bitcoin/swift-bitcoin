import Testing
import Foundation
@testable import BitcoinBlockchain // @testable for signatureHash(), SigHashType
import BitcoinCrypto
import BitcoinBase

struct BitcoinServiceTests {

    /// Tests mining empty blocks, spending a coinbase transaction and mine again.
    @Test("Mine and spend")
    func mineAndSpend() async throws {

        // Generate a secret key, corresponding public key, hash and address.
        let secretKey = SecretKey()
        let publicKey = secretKey.publicKey
        let publicKeyHash = Data(Hash160.hash(data: publicKey.data))

        // Instantiate a fresh Bitcoin service (regtest).
        let service = BitcoinService()

        // Create the genesis block.
        await service.createGenesisBlock()

        // Mine 100 blocks so block 1's coinbase output reaches maturity.
        for _ in 0 ..< 100 {
            await service.generateTo(publicKey)
        }

        // Grab block 1's coinbase transaction and output.
        let previousTransaction = await service.getBlock(1).transactions[0]
        let prevout = previousTransaction.outputs[0]
        let outpoint = previousTransaction.outpoint(0)!

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
        let sighash = unsignedTransaction.signatureHash(sighashType: .all, inputIndex: 0, prevout: prevout, scriptCode: prevout.script.data)

        // Obtain the signature using our secret key and append the signature hash type.
        let signature = try #require(Signature(messageHash: sighash, secretKey: secretKey, type: .ecdsa))
        let sig = signature.data + [SighashType.all.value]

        // Sign our input by including the signature and public key.
        let signedInput = TransactionInput(
            outpoint: unsignedInput.outpoint,
            sequence: unsignedInput.sequence,
            script: .init([
                .pushBytes(sig),
                .pushBytes(publicKey.data)
            ]),
            witness: unsignedInput.witness)

        // Put the signed input back into the transaction.
        let signedTransaction = BitcoinTransaction(
            version: unsignedTransaction.version,
            locktime: unsignedTransaction.locktime,
            inputs: [signedInput],
            outputs: unsignedTransaction.outputs)

        // Make sure the transaction was signed correctly by verifying the scripts.
        #expect(signedTransaction.verifyScript(prevouts: [prevout]))

        // Submit the signed transaction to the mempool.
        await service.addTransaction(signedTransaction)
        let mempoolBefore = await service.mempool.count
        #expect(mempoolBefore == 1)

        // Let's mine another block to confirm our transaction.
        await service.generateTo(publicKey)
        let mempoolAfter = await service.mempool.count

        // Verify the mempool is empty once again.
        #expect(mempoolAfter == 0)
        let blocks = await service.blockTransactions.count
        #expect(blocks == 102)
        let lastBlockTtransactions = try #require(await service.blockTransactions.last)
        // Verify our transaction was confirmed in a block.
        #expect(lastBlockTtransactions[1] == signedTransaction)
    }

    @Test("Difficulty Target")
    func difficultyTarget() async throws {
        let difficultyBits = 0x207fffff
        let powLimitBE = Data([0x7f, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]) // Regtest
        let powLimitLE = Data(powLimitBE.reversed())
        let powLimitTarget = DifficultyTarget(powLimitLE)
        #expect(powLimitTarget.data == powLimitLE)
        let powLimitCompact = powLimitTarget.toCompact()
        #expect(powLimitCompact == difficultyBits)

        var neg: Bool = true
        var over: Bool = true
        let powLimitTarget_ = DifficultyTarget(compact: powLimitCompact, negative: &neg, overflow: &over)
        #expect(!powLimitTarget_.isZero && !neg && !over)
        let powLimitLE_ = powLimitTarget_.data
        #expect(powLimitLE_.reversed().hex == "7fffff0000000000000000000000000000000000000000000000000000000000")
    }

    @Test("Difficulty Adjustment")
    func difficultyAdjustment() async throws {
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

        #expect(genesisBlock.header.target == 0x207fffff)
        let genesisDate = genesisBlock.header.time
        var date = genesisDate
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .gmt

        let publicKey = try #require(PublicKey(compressed: [0x03, 0x5a, 0xc9, 0xd1, 0x48, 0x78, 0x68, 0xec, 0xa6, 0x4e, 0x93, 0x2a, 0x06, 0xee, 0x8d, 0x6d, 0x2e, 0x89, 0xd9, 0x86, 0x59, 0xdb, 0x7f, 0x24, 0x74, 0x10, 0xd3, 0xe7, 0x9f, 0x88, 0xf8, 0xd0, 0x05])) // Testnet p2pkh address  miueyHbQ33FDcjCYZpVJdC7VBbaVQzAUg5
        for i in 1...15 {
            let minutes = if i < 5 { 4 } else if i < 10 { 2 } else { 4 }
            date = calendar.date(byAdding: .minute, value: minutes, to: date)!
            await service.generateTo(publicKey, blockTime: date)
            let header = await service.headers.last!
            let expectedTarget = if (1...4).contains(i) {
                0x207fffff // 0x7fffff0000000000000000000000000000000000000000000000000000000000 DifficultyTarget(compact: block.header.target).data.reversed().hex
            } else if (5...9).contains(i) {
                0x1f6d386d // 0x006d386d00000000000000000000000000000000000000000000000000000000
            } else if (10...14).contains(i) {
                0x1f576057 // 0x0057605700000000000000000000000000000000000000000000000000000000
            } else {
                0x1f1e9351 // 0x001e935100000000000000000000000000000000000000000000000000000000
            }
            #expect(header.target == expectedTarget)
        }
    }

    @Test("Difficulty", arguments: [
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
    ])
    func difficulty(compact: Int, expected: Double) async throws {
        var negative = true
        var overflow = true
        let target = DifficultyTarget(compact: compact, negative: &negative, overflow: &overflow)
        #expect(!target.isZero)
        #expect(!overflow)
        #expect(target.toCompact(negative: negative) == compact)
        #expect(isApproximatelyEqual(DifficultyTarget.getDifficulty(compact), to: expected, absoluteTolerance: 0.00001))
    }
}

fileprivate func isApproximatelyEqual(
    _ value: Double,
    to other: Double,
    absoluteTolerance: Double,
    relativeTolerance: Double = 0
  ) -> Bool {
    precondition(
      absoluteTolerance >= 0 && absoluteTolerance.isFinite,
      "absoluteTolerance should be non-negative and finite, " +
      "but is \(absoluteTolerance)."
    )
    precondition(
      relativeTolerance >= 0 && relativeTolerance <= 1,
      "relativeTolerance should be non-negative and <= 1, " +
      "but is \(relativeTolerance)."
    )
    if value == other { return true }
    let delta = value - other
    let scale = max(value, other)
    let bound = max(absoluteTolerance, scale*relativeTolerance)
    return delta.isFinite && delta <= bound
}
