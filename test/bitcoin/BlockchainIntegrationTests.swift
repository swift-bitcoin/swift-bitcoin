import Testing
import Foundation
import BitcoinCrypto
import BitcoinBase
import BitcoinBlockchain
import BitcoinWallet

struct BlockchainIntegrationTests {

    /// Checks that some of the newly learned block's transaction might already be in our mempool.
    @Test("New block transaction already in mempool")
    func blockTxInMempool() async throws {
        let aliceKey = SecretKey()
        let alicePK = aliceKey.pubkey
        let bobKey = SecretKey()
        let bobPK = bobKey.pubkey
        let carolKey = SecretKey()
        let carolPK = carolKey.pubkey
        let derekKey = SecretKey()
        let derekPK = derekKey.pubkey
        let errolKey = SecretKey()
        let errolPK = errolKey.pubkey
        let fionaKey = SecretKey()
        let fionaPK = fionaKey.pubkey
        let gabrielKey = SecretKey()
        let gabrielPK = gabrielKey.pubkey

        let alice = BlockchainService()
        await alice.start()
        let bob = BlockchainService()
        await bob.start()

        let genesisBlock = await alice.genesisBlock
        #expect(await bob.genesisBlock == genesisBlock)

        // Mine 100 blocks so block 1's coinbase output reaches maturity.
        var newBlocks = [Block]()
        for _ in 1 ... 100 {
            let newBlock = try #require(await alice.generateTo(alicePK))
            newBlocks.append(newBlock)
        }
        #expect(await alice.height == 100)

        for i in 0 ..< 100 {
            try await bob.processBlock(newBlocks[i])
        }
        #expect(await bob.height == 100)

        // Grab block 1's coinbase transaction and output.
        let coinbaseTx = newBlocks[0].txs[0]

        var t_a3 = Transaction(
            ins: [.init(outpoint: coinbaseTx.outpoint(0))],
            outs: [
                .init(value: 10, script: .payToPubkeyHash(bobPK)),
                .init(value: 15, script: .payToPubkeyHash(carolPK)),
                .init(value: 20, script: .payToPubkeyHash(derekPK))
            ])

        var signer = TransactionSigner(tx: t_a3, prevouts: [coinbaseTx.outs[0]])
        signer.sign(input: 0, with: aliceKey)
        t_a3 = signer.tx

        #expect(await alice.mempool.count == 0)
        try await alice.addTransaction(t_a3)
        #expect(await alice.mempool.count == 1)

        #expect(await bob.mempool.count == 0)
        try await bob.addTransaction(t_a3)
        #expect(await bob.mempool.count == 1)

        let aliceLastBlock = try #require(await alice.generateTo(alicePK))
        #expect(await alice.mempool.count == 0)

        #expect(await bob.height == 100)
        try await bob.processBlock(aliceLastBlock)
        #expect(await bob.height == 101)
        #expect(await bob.mempool.count == 0)

        var tA1_b2 = Transaction(
            ins: [.init(outpoint: t_a3.outpoint(1))],
            outs: [
                .init(value: 10, script: .payToPubkeyHash(derekPK)),
                .init(value: 5, script: .payToPubkeyHash(errolPK))
            ])
        signer = TransactionSigner(tx: tA1_b2, prevouts: [t_a3.outs[1]])
        signer.sign(input: 0, with: carolKey)
        tA1_b2 = signer.tx

        var tA0_A2_c2 = Transaction(
            ins: [
                .init(outpoint: t_a3.outpoint(0)),
                .init(outpoint: t_a3.outpoint(2))
            ],
            outs: [
                .init(value: 15, script: .payToPubkeyHash(fionaPK)),
                .init(value: 15, script: .payToPubkeyHash(gabrielPK))
            ])
        signer = TransactionSigner(tx: tA0_A2_c2, prevouts: [t_a3.outs[0], t_a3.outs[2]])
        signer.sign(input: 0, with: bobKey)
        signer.sign(input: 1, with: derekKey)
        tA0_A2_c2 = signer.tx

        try await bob.addTransaction(tA1_b2)
        #expect(await bob.mempool.count == 1)

        try await bob.addTransaction(tA0_A2_c2)
        #expect(await bob.mempool.count == 2)

        try await alice.addTransaction(tA0_A2_c2)
        #expect(await alice.mempool.count == 1)


        let bobLastBlock = try #require(await bob.generateTo(bobPK))
        #expect(await bob.mempool.isEmpty)
        #expect(bobLastBlock.txs[2] == tA0_A2_c2)
        #expect(await bob.height == 102)

        try await alice.processBlock(bobLastBlock)
        #expect(await alice.mempool.isEmpty)

        await alice.stop()
        await bob.stop()
    }

    @Test func blockUndo() async throws {
        let blockchain = BlockchainService(params: .swiftTesting)
        await blockchain.start()

        let aliceKey = SecretKey()
        let alicePK = aliceKey.pubkey

        let block = try #require(await blockchain.generateTo(alicePK))
        let coinbaseTx1 = block.txs[0]

        let utxoSet1 = await blockchain.currentUTXOSet()

        let expectedUTXOSet1 = [
            coinbaseTx1.outpoint(0): UnspentOutput(coinbaseTx1.outs[0], height: 1, isCoinbase: true),
            coinbaseTx1.outpoint(1): UnspentOutput(coinbaseTx1.outs[1], height: 1, isCoinbase: true)
        ]

        #expect(utxoSet1 == expectedUTXOSet1)

        let outs1 = [
            TransactionOutput(value: 100_000_000, script: .payToPubkeyHash(alicePK)),
            .init(value: 200_000_000, script: .payToPubkeyHash(alicePK)),
            .init(value: 300_000_000, script: .payToPubkeyHash(alicePK)),
            .init(value: 400_000_000, script: .payToPubkeyHash(alicePK)),
            .init(value: 500_000_000, script: .payToPubkeyHash(alicePK)),
            .init(value: 3_499_999_999, script: .payToPubkeyHash(alicePK))
        ]
        var tx1 = Transaction(
            ins: [.init(outpoint: coinbaseTx1.outpoint(0))],
            outs: outs1)

        var signer = TransactionSigner(tx: tx1, prevouts: [coinbaseTx1.outs[0]])
        signer.sign(input: 0, with: aliceKey)
        tx1 = signer.tx

        try await blockchain.addTransaction(tx1)

        var tx2 = Transaction(
            ins: [.init(outpoint: tx1.outpoint(5))],
            outs: [
            TransactionOutput(value: 600_000_000, script: .payToPubkeyHash(alicePK)),
            .init(value: 700_000_000, script: .payToPubkeyHash(alicePK)),
            .init(value: 800_000_000, script: .payToPubkeyHash(alicePK)),
            .init(value: 900_000_000, script: .payToPubkeyHash(alicePK)),
            .init(value: 499_999_999, script: .payToPubkeyHash(alicePK))
        ])

        var signer2 = TransactionSigner(tx: tx2, prevouts: [tx1.outs[5]])
        signer2.sign(input: 0, with: aliceKey)
        tx2 = signer2.tx

        try await blockchain.addTransaction(tx2)


        let block2 = try #require(await blockchain.generateTo(alicePK))
        let coinbaseTx2 = block2.txs[0]

        let utxoSet2 = await blockchain.currentUTXOSet()

        let expectedUTXOSet2 = [
            coinbaseTx1.outpoint(1): UnspentOutput(coinbaseTx1.outs[1], height: 1, isCoinbase: true),
            coinbaseTx2.outpoint(0): UnspentOutput(coinbaseTx2.outs[0], height: 2, isCoinbase: true),
            coinbaseTx2.outpoint(1): UnspentOutput(coinbaseTx2.outs[1], height: 2, isCoinbase: true),
            tx1.outpoint(0): UnspentOutput(tx1.outs[0], height: 2),
            tx1.outpoint(1): UnspentOutput(tx1.outs[1], height: 2),
            tx1.outpoint(2): UnspentOutput(tx1.outs[2], height: 2),
            tx1.outpoint(3): UnspentOutput(tx1.outs[3], height: 2),
            tx1.outpoint(4): UnspentOutput(tx1.outs[4], height: 2),
            tx2.outpoint(0): UnspentOutput(tx2.outs[0], height: 2),
            tx2.outpoint(1): UnspentOutput(tx2.outs[1], height: 2),
            tx2.outpoint(2): UnspentOutput(tx2.outs[2], height: 2),
            tx2.outpoint(3): UnspentOutput(tx2.outs[3], height: 2),
            tx2.outpoint(4): UnspentOutput(tx2.outs[4], height: 2)
        ]

        #expect(utxoSet2.count == expectedUTXOSet2.count)
        #expect(utxoSet2 == expectedUTXOSet2)

        #expect(await blockchain.bestHeight == 2)

        try await blockchain.undoLastBlock()

        let utxoSet1_ = await blockchain.currentUTXOSet()
        #expect(utxoSet1_.count == expectedUTXOSet1.count)
        #expect(utxoSet1_ == expectedUTXOSet1)

        #expect(await blockchain.bestHeight == 1)

        await blockchain.stop()
    }

    @Test func simpleReorg() async throws {
        let alice = BlockchainService(params: .swiftTesting)
        await alice.start()

        let bob = BlockchainService(params: .swiftTesting)
        await bob.start()

        let carol = BlockchainService(params: .swiftTesting)
        await carol.start()

        let aliceKey = SecretKey()
        let alicePK = aliceKey.pubkey

        let blockA = try #require(await alice.generateTo(alicePK))

        try await bob.processBlock(blockA, immediate: true)
        try await carol.processBlock(blockA, immediate: true)

        let coinbaseTx = blockA.txs[0]
        var tx = Transaction(
            ins: [.init(outpoint: coinbaseTx.outpoint(0))],
            outs: [
            .init(value: 4_999_999_999, script: .payToPubkeyHash(alicePK))
        ])

        var signer = TransactionSigner(tx: tx, prevouts: [coinbaseTx.outs[0]])
        signer.sign(input: 0, with: aliceKey)
        tx = signer.tx

        try await alice.addTransaction(tx)

        let blockB = try #require(await alice.generateTo(alicePK))
        try await carol.processBlock(blockB, immediate: true)

        #expect(await carol.chainTip == blockB.id)

        let blockBB = try #require(await bob.generateTo(alicePK))
        try await carol.processBlock(blockBB, immediate: true)

        #expect(await carol.chainTip == blockB.id)

        let blockCC = try #require(await bob.generateTo(alicePK))
        try await carol.processBlock(blockCC, immediate: true)

        #expect(await carol.chainTip == blockCC.id)

        await alice.stop()
        await bob.stop()
        await carol.stop()
    }

}
