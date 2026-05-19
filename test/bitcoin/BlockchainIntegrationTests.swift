import Testing
import struct NIOFileSystem.FilePath
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

        let alice = try await BlockchainService()
        let bob = try await BlockchainService()

        let genesisBlock = await alice.genesisBlock
        #expect(await bob.genesisBlock == genesisBlock)

        // Mine 100 blocks so block 1's coinbase output reaches maturity.
        var newBlocks = [Block]()
        for _ in 1 ... 100 {
            let newBlock = try #require(await alice.generateTo(alicePK))
            newBlocks.append(newBlock)
        }
        #expect(await alice.headers == 100)

        for i in 0 ..< 100 {
            try await bob.processBlock(newBlocks[i])
        }
        #expect(await bob.headers == 100)

        // Grab block 1's coinbase transaction and output.
        let coinbaseTx = newBlocks[0].txs[0]

        var t_a3 = Transaction(
            ins: [.init(outpoint: coinbaseTx.outpoint(0))],
            outs: [
                .init(value: 1000, script: .payToPubkeyHash(bobPK)),
                .init(value: 1500, script: .payToPubkeyHash(carolPK)),
                .init(value: 2000, script: .payToPubkeyHash(derekPK))
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

        #expect(await bob.headers == 100)
        try await bob.processBlock(aliceLastBlock)
        #expect(await bob.headers == 101)
        #expect(await bob.mempool.count == 0)

        var tA1_b2 = Transaction(
            ins: [.init(outpoint: t_a3.outpoint(1))],
            outs: [
                .init(value: 1000, script: .payToPubkeyHash(derekPK)),
                .init(value: 500, script: .payToPubkeyHash(errolPK))
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
                .init(value: 1500, script: .payToPubkeyHash(fionaPK)),
                .init(value: 1500, script: .payToPubkeyHash(gabrielPK))
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
        #expect(await bob.headers == 102)

        try await alice.processBlock(bobLastBlock)
        #expect(await alice.mempool.isEmpty)
    }

    @Test func blockUndo() async throws {
        let blockchain = try await BlockchainService(params: .swiftTesting)

        let aliceKey = SecretKey()
        let alicePK = aliceKey.pubkey

        let block = try #require(await blockchain.generateTo(alicePK))
        let coinbaseTx1 = block.txs[0]

        let utxoSet1 = await blockchain.unspentOutputs

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
        #expect(await blockchain.mempool.count == 1)

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
        #expect(await blockchain.mempool.count == 2)

        let block2 = try #require(await blockchain.generateTo(alicePK))
        let coinbaseTx2 = block2.txs[0]

        let utxoSet2 = await blockchain.unspentOutputs

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

        #expect(await blockchain.height == 2)

        try await blockchain.undoLastBlock()

        let utxoSet1_ = await blockchain.unspentOutputs
        #expect(utxoSet1_.count == expectedUTXOSet1.count)
        #expect(utxoSet1_ == expectedUTXOSet1)

        #expect(await blockchain.height == 1)
    }

    @Test func simpleReorg() async throws {
        let alice = try await BlockchainService(params: .swiftTesting)

        let bob = try await BlockchainService(params: .swiftTesting)

        let carol = try await BlockchainService(params: .swiftTesting)

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

        let tips = await carol.chainTips

        let expectedTips: [ChainTipSummary] = [
            .init(tip: blockCC.id, height: 3, branchLength: 4, status: .active),
            .init(tip: blockB.id, height: 2, branchLength: 1, status: .stale)
        ]
        #expect(tips == expectedTips)
    }

    /// Makes the active chain switch twice. In the first reorg the last block become stale. Afterwards another reorganization reactivates it and two different blocks turn stale.
    @Test(arguments: [false, true]) func reReorg(persistence: Bool) async throws {

        let fm = FileManager.default
        let disambiguator = UInt.random(in: UInt.min ... UInt.max)

        func dataDir(_ index: Int) throws -> FilePath {
            let url = fm.temporaryDirectory.appendingPathComponent(disambiguator.description).appendingPathComponent(#fileID).appendingPathComponent(#function).appendingPathComponent(index.description)
            let path = FilePath(url.relativePath)
            try? fm.removeItem(atPath: path.string)
            try fm.createDirectory(at: url, withIntermediateDirectories: true)
            return path
        }

        let dataPath = persistence ? try dataDir(0) : nil
        let dataPath1 = persistence ? try dataDir(1) : nil
        let dataPath2 = persistence ? try dataDir(2) : nil

        defer {
            if let dataPath, let dataPath1, let dataPath2 {
                try? fm.removeItem(atPath: dataPath.string)
                try? fm.removeItem(atPath: dataPath1.string)
                try? fm.removeItem(atPath: dataPath2.string)
            }
        }

        let satoshi = try await BlockchainService(params: .swiftTesting, config: persistence ? .init(dataLocation: .custom(path: dataPath!.string)) : .init())

        let alice = try await BlockchainService(params: .swiftTesting, config: persistence ?.init(dataLocation: .custom(path: dataPath1!.string)) : .init())
        let bob = try await BlockchainService(params: .swiftTesting, config: persistence ? .init(dataLocation: .custom(path: dataPath2!.string)) : .init())

        let satoshiKey = SecretKey()
        let satoshiID = satoshiKey.pubkey

        let aliceKey = SecretKey()
        let aliceID = aliceKey.pubkey

        let bobKey = SecretKey()
        let bobID = bobKey.pubkey

        let blockA = try #require(await satoshi.generateTo(satoshiID)) // S: 5B, A: 0, B: 0
        let coinbaseTxA = blockA.txs[0]

        let expectedUTXOSetA = [
            coinbaseTxA.outpoint(0): UnspentOutput(coinbaseTxA.outs[0], height: 1, isCoinbase: true),
            coinbaseTxA.outpoint(1): UnspentOutput(coinbaseTxA.outs[1], height: 1, isCoinbase: true)
        ]

        #expect(await satoshi.unspentOutputs == expectedUTXOSetA)

        try await alice.processBlock(blockA, immediate: true)
        try await bob.processBlock(blockA, immediate: true)

        #expect(await alice.unspentOutputs == expectedUTXOSetA)
        #expect(await bob.unspentOutputs == expectedUTXOSetA)

        var tx1 = Transaction(
            ins: [.init(outpoint: coinbaseTxA.outpoint(0))],
            outs: [
                .init(value: 9000, script: .payToPubkeyHash(aliceID)),
                .init(value: 1000, script: .payToPubkeyHash(bobID))
        ])

        var signer1 = TransactionSigner(tx: tx1, prevouts: [coinbaseTxA.outs[0]])
        signer1.sign(input: 0, with: satoshiKey)
        tx1 = signer1.tx

        try await satoshi.addTransaction(tx1)
        try await alice.addTransaction(tx1)

        let blockB = try #require(await alice.generateTo(satoshiID)) // S: 9B+, A: 9, B: 1
        let coinbaseTxB = blockB.txs[0]

        let expectedUTXOSetB = [
            coinbaseTxA.outpoint(1): UnspentOutput(coinbaseTxA.outs[1], height: 1, isCoinbase: true),
            coinbaseTxB.outpoint(0): UnspentOutput(coinbaseTxB.outs[0], height: 2, isCoinbase: true),
            coinbaseTxB.outpoint(1): UnspentOutput(coinbaseTxB.outs[1], height: 2, isCoinbase: true),
            tx1.outpoint(0): UnspentOutput(tx1.outs[0], height: 2, isCoinbase: false),
            tx1.outpoint(1): UnspentOutput(tx1.outs[1], height: 2, isCoinbase: false)
        ]
        #expect(await alice.unspentOutputs == expectedUTXOSetB)

        try await satoshi.processBlock(blockB, immediate: true)
        #expect(await satoshi.unspentOutputs == expectedUTXOSetB)

        var tx11 = Transaction(
            ins: [.init(outpoint: coinbaseTxA.outpoint(0))],
            outs: [
                .init(value: 2000, script: .payToPubkeyHash(aliceID)),
                .init(value: 8000, script: .payToPubkeyHash(bobID))
        ])

        var signer11 = TransactionSigner(tx: tx11, prevouts: [coinbaseTxA.outs[0]])
        signer11.sign(input: 0, with: satoshiKey)
        tx11 = signer11.tx

        try await bob.addTransaction(tx11)

        let blockBB = try #require(await bob.generateTo(satoshiID)) // S: 9B+, A: 2, B: 8
        let coinbaseTxBB = blockBB.txs[0]

        let expectedUTXOSetBB = [
            coinbaseTxA.outpoint(1): UnspentOutput(coinbaseTxA.outs[1], height: 1, isCoinbase: true),
            coinbaseTxBB.outpoint(0): UnspentOutput(coinbaseTxBB.outs[0], height: 2, isCoinbase: true),
            coinbaseTxBB.outpoint(1): UnspentOutput(coinbaseTxBB.outs[1], height: 2, isCoinbase: true),
            tx11.outpoint(0): UnspentOutput(tx11.outs[0], height: 2, isCoinbase: false),
            tx11.outpoint(1): UnspentOutput(tx11.outs[1], height: 2, isCoinbase: false)
        ]
        #expect(await bob.unspentOutputs == expectedUTXOSetBB)

        var tx2 = Transaction(
            ins: [.init(outpoint: tx1.outpoint(0))],
            outs: [
                .init(value: 6000, script: .payToPubkeyHash(aliceID)),
                .init(value: 3000, script: .payToPubkeyHash(bobID))
        ])

        var signer2 = TransactionSigner(tx: tx2, prevouts: [tx1.outs[0]])
        signer2.sign(input: 0, with: aliceKey)
        tx2 = signer2.tx

        try await satoshi.addTransaction(tx2)
        try await alice.addTransaction(tx2)

        #expect(await satoshi.mempool.count == 1)
        #expect(await alice.mempool.count == 1)

        var tx22 = Transaction(
            ins: [.init(outpoint: tx11.outpoint(1))],
            outs: [
                .init(value: 5000, script: .payToPubkeyHash(bobID)),
                .init(value: 3000, script: .payToPubkeyHash(aliceID))
        ])

        var signer22 = TransactionSigner(tx: tx22, prevouts: [tx11.outs[1]])
        signer22.sign(input: 0, with: bobKey)
        tx22 = signer22.tx

        // try await satoshi.addTransaction(tx22)
        try await bob.addTransaction(tx22)

        #expect(await bob.mempool.count == 1)

        let blockCC = try #require(await bob.generateTo(satoshiID))
        let coinbaseTxCC = blockCC.txs[0]

        #expect(await bob.mempool.count == 0)

        let expectedUTXOSetCC = [
            coinbaseTxA.outpoint(1): UnspentOutput(coinbaseTxA.outs[1], height: 1, isCoinbase: true),
            coinbaseTxBB.outpoint(0): UnspentOutput(coinbaseTxBB.outs[0], height: 2, isCoinbase: true),
            coinbaseTxBB.outpoint(1): UnspentOutput(coinbaseTxBB.outs[1], height: 2, isCoinbase: true),
            coinbaseTxCC.outpoint(0): UnspentOutput(coinbaseTxCC.outs[0], height: 3, isCoinbase: true),
            coinbaseTxCC.outpoint(1): UnspentOutput(coinbaseTxCC.outs[1], height: 3, isCoinbase: true),
            tx11.outpoint(0): UnspentOutput(tx11.outs[0], height: 2, isCoinbase: false),
            tx22.outpoint(0): UnspentOutput(tx22.outs[0], height: 3, isCoinbase: false),
            tx22.outpoint(1): UnspentOutput(tx22.outs[1], height: 3, isCoinbase: false)
        ]

        #expect(await bob.unspentOutputs == expectedUTXOSetCC)

        try await satoshi.processBlock(blockBB, immediate: true)
        #expect(await satoshi.mempool.count == 1)
        #expect(await satoshi.unspentOutputs == expectedUTXOSetB)

        try await satoshi.processHeaders([blockCC.header])
        #expect(await satoshi.unspentOutputs == expectedUTXOSetA)

        try await satoshi.processBlock(blockCC, immediate: true)
        #expect(await satoshi.mempool.count == 0)
        #expect(await satoshi.unspentOutputs == expectedUTXOSetCC)

        let blockC = try #require(await alice.generateTo(satoshiID))
        let coinbaseTxC = blockC.txs[0]

        let blockD = try #require(await alice.generateTo(satoshiID))
        let coinbaseTxD = blockD.txs[0]

        let expectedUTXOSetD = [
            coinbaseTxA.outpoint(1): UnspentOutput(coinbaseTxA.outs[1], height: 1, isCoinbase: true),
            coinbaseTxB.outpoint(0): UnspentOutput(coinbaseTxB.outs[0], height: 2, isCoinbase: true),
            coinbaseTxB.outpoint(1): UnspentOutput(coinbaseTxB.outs[1], height: 2, isCoinbase: true),
            coinbaseTxC.outpoint(0): UnspentOutput(coinbaseTxC.outs[0], height: 3, isCoinbase: true),
            coinbaseTxC.outpoint(1): UnspentOutput(coinbaseTxC.outs[1], height: 3, isCoinbase: true),
            coinbaseTxD.outpoint(0): UnspentOutput(coinbaseTxD.outs[0], height: 4, isCoinbase: true),
            coinbaseTxD.outpoint(1): UnspentOutput(coinbaseTxD.outs[1], height: 4, isCoinbase: true),
            tx1.outpoint(1): UnspentOutput(tx1.outs[1], height: 2, isCoinbase: false),
            tx2.outpoint(0): UnspentOutput(tx2.outs[0], height: 3, isCoinbase: false),
            tx2.outpoint(1): UnspentOutput(tx2.outs[1], height: 3, isCoinbase: false)
        ]

        #expect(await alice.unspentOutputs == expectedUTXOSetD)

        try await satoshi.processBlock(blockC, immediate: true)
        #expect(await satoshi.unspentOutputs == expectedUTXOSetCC)

        try await satoshi.processHeaders([blockD.header])
        #expect(await satoshi.unspentOutputs == expectedUTXOSetB)

        try await satoshi.processBlock(blockD, immediate: true)
        #expect(await satoshi.unspentOutputs == expectedUTXOSetD)

        let tips = await satoshi.chainTips

        let expectedTips: [ChainTipSummary] = [
            .init(tip: blockD.id, height: 4, branchLength: 5, status: .active),
            .init(tip: blockCC.id, height: 3, branchLength: 2, status: .stale)
        ]
        #expect(tips == expectedTips)

        await withTaskGroup {
            $0.addTask {
                await satoshi.shutdown()
                await alice.shutdown()
                await bob.shutdown()
            }
        }
    }
}
