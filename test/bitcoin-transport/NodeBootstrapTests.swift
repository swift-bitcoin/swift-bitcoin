import Testing
import BitcoinCrypto
import Foundation
import AsyncAlgorithms
import BitcoinBase
import BitcoinWallet
import BitcoinBlockchain
@testable import BitcoinTransport

private let secretKey = SecretKey([0x49, 0xc3, 0xa4, 0x4b, 0xf0, 0xe2, 0xb8, 0x1e, 0x4a, 0x74, 0x11, 0x02, 0xb4, 0x08, 0xe3, 0x11, 0x70, 0x2c, 0x7e, 0x3b, 0xe0, 0x21, 0x5c, 0xa2, 0xc4, 0x66, 0xb3, 0xb5, 0x4d, 0x9c, 0x54, 0x63])!

private let pubkey = PublicKey([0x02, 0xc8, 0xd2, 0x1f, 0x79, 0x52, 0x9d, 0xee, 0xaa, 0x27, 0x69, 0x19, 0x8d, 0x3d, 0xf6, 0x20, 0x9a, 0x06, 0x4c, 0x99, 0x15, 0xae, 0x55, 0x7f, 0x7a, 0x9d, 0x01, 0xd7, 0x24, 0x59, 0x0d, 0x63, 0x34])!

/// Initializing node/peer state to avoid simulating the message sequence that would lead to that state.
struct NodeBootstrapTests {

    @Test("Ping Pong")
    func pingPong() async throws {
        // Alice's node
        let peerB = 0
        let alice = await NodeService(
            blockchain: try await .init(params: .swiftTesting),
            config: .init(keepAliveFrequency: nil),
            state: NodeState(peers: [peerB : makePeerState()])
        )
        await #expect(alice.state.peers[peerB]!.handshakeComplete)

        // Bob's node
        let peerA = 0
        let bob = await NodeService(
            blockchain: try await .init(params: .swiftTesting),
            config: .init(keepAliveFrequency: nil),
            state: NodeState(peers: [peerA : makePeerState(true)])
        )
        await #expect(bob.state.peers[peerA]!.handshakeComplete)

        // Channels
        var aliceToBob = await alice.channel(for: peerB).makeAsyncIterator()
        // var bobToAlice = await bob.getChannel(for: peerA).makeAsyncIterator()

        // Begin testing
        Task {
            await alice.sendPingTo(peerB)
        }
        // Alice --(ping)->> …
        let messageAB0_ping = try #require(await aliceToBob.next())
        #expect(messageAB0_ping.command == .ping)

        let ping0 = try #require(PingMessage(messageAB0_ping.payload))
        var lastPingNonce = await alice.state.peers[peerB]!.lastPingNonce
        #expect(lastPingNonce != nil)

        // … --(ping)->> Bob
        try await bob.processMessage(messageAB0_ping, from: peerA)

        // Bob --(pong)->> …
        let messageBA0_pong = try #require(await bob.popMessage(peerA))
        #expect(messageBA0_pong.command == .pong)

        let pong0 = try #require(PongMessage(messageBA0_pong.payload))
        #expect(ping0.nonce == pong0.nonce)

        // … --(pong)->> Alice
        try await alice.processMessage(messageBA0_pong, from: peerB) // No response expected

        lastPingNonce = await alice.state.peers[peerB]!.lastPingNonce
        #expect(lastPingNonce == nil)

        await cleanup([alice, bob])
    }

    @Test("Empty block relay")
    func emptyBlockRelay() async throws {
        // Alices's node
        let peerB = 0
        let alice = await NodeService(
            blockchain: try await .init(params: .swiftTesting),
            config: .init(keepAliveFrequency: nil),
            state: NodeState(peers: [peerB : makePeerState()])
        )

        // Bob's node
        let peerA = 0
        let peerC = 1 // Carol on Bob's node
        let bob = await NodeService(blockchain: try await .init(params: .swiftTesting), config: .init(keepAliveFrequency: nil), state: NodeState(peers: [peerA : makePeerState(true), peerC : makePeerState()]))

        // Carol's node
        let carolPeerB = 0 // Bob on Carol's node
        let carol = await NodeService(blockchain: try await .init(params: .swiftTesting), config: .init(keepAliveFrequency: nil), state: NodeState(peers: [carolPeerB : makePeerState(true)]))

        // Peer channels
        var aliceToBob = await alice.channel(for: peerB).makeAsyncIterator()
        var bobToCarol = await bob.channel(for: peerC).makeAsyncIterator()

        // Begin testing

        let block0 = try #require(await alice.blockchain.generateTo(pubkey))

        // Alice --(cmpctblock)->> …
        let messageAB0_cmpctblock = try #require(await aliceToBob.next())
        #expect(messageAB0_cmpctblock.command == .cmpctblock)

        let cmpctblock0 = try #require(CompactBlockMessage(messageAB0_cmpctblock.payload))
        #expect(cmpctblock0.header == block0.header)

        // … --(cmpctblock)->> Bob
        try await bob.processMessage(messageAB0_cmpctblock, from: peerA)

        // Bob --(cmpctblock)->> …
        let messageBC0_cmpctblock = try #require(await bobToCarol.next())
        #expect(messageBC0_cmpctblock.command == .cmpctblock)

        let cmpctblock1 = try #require(CompactBlockMessage(messageBC0_cmpctblock.payload))
        #expect(cmpctblock1.header == block0.header)

        // … --(cmpctblock)->> Carol
        try await carol.processMessage(messageBC0_cmpctblock, from: carolPeerB)

        let bobsHeight0 = await bob.blockchain.headers
        #expect(await alice.blockchain.headers == bobsHeight0)
        #expect(await carol.blockchain.headers == bobsHeight0)

        // Generate another block
        let block1 = try #require(await alice.blockchain.generateTo(pubkey))

        // Alice --(cmpctblock)->> …
        let messageAB1_cmpctblock = try #require(await aliceToBob.next())
        #expect(messageAB1_cmpctblock.command == .cmpctblock)

        let cmpctblock2 = try #require(CompactBlockMessage(messageAB1_cmpctblock.payload))
        #expect(cmpctblock2.header == block1.header)

        // … --(cmpctblock)->> Bob
        try await bob.processMessage(messageAB1_cmpctblock, from: peerA)

        // let bobBlock1 = try #require(await bobBlocks.next())
        // Task { await bob.handleBlock(bobBlock1) }

        // Bob --(cmpctblock)->> …
        let messageBC1_cmpctblock = try #require(await bobToCarol.next())
        #expect(messageBC1_cmpctblock.command == .cmpctblock)

        let cmpctblock3 = try #require(CompactBlockMessage(messageBC1_cmpctblock.payload))
        #expect(cmpctblock3.header == block1.header)

        // … --(cmpctblock)->> Carol
        try await carol.processMessage(messageBC1_cmpctblock, from: carolPeerB)

        let bobsHeight1 = await bob.blockchain.headers
        #expect(await alice.blockchain.headers == bobsHeight1)
        #expect(await carol.blockchain.headers == bobsHeight1)

        await cleanup([alice, bob, carol])
    }

    @Test("Mempool transaction relay")
    func mempoolTxRelay() async throws {
        // Alice's node
        let peerB = 0
        let alice = await NodeService(
            blockchain: try await .init(params: .swiftTesting),
            config: .init(keepAliveFrequency: nil),
            state: NodeState(peers: [peerB : makePeerState()])
        )

        // Bob's node
        let peerA = 0
        let peerC = 1 // Carol on Bob's node
        let bob = await NodeService(blockchain: try await .init(params: .swiftTesting), config: .init(keepAliveFrequency: nil), state: NodeState(peers: [peerA : makePeerState(true), peerC : makePeerState()]))

        // Carol node
        let carolPeerB = 0 // Bob on Carol's node
        let carol = await NodeService(blockchain: try await .init(params: .swiftTesting), config: .init(keepAliveFrequency: nil), state: NodeState(peers: [carolPeerB : makePeerState(true)]))

        // Peer channels
        var aliceToBob = await alice.channel(for: peerB).makeAsyncIterator()
        var bobToCarol = await bob.channel(for: peerC).makeAsyncIterator()

        // Begin testing

        // Setup blockchains
        let aliceBlock1 = try #require(await alice.blockchain.generateTo(pubkey))

        // Alice --(cmpctblock)->> …
        let messageAB0_cmpctblock = try #require(await aliceToBob.next())
        #expect(messageAB0_cmpctblock.command == .cmpctblock)

        let cmpctblock0 = try #require(CompactBlockMessage(messageAB0_cmpctblock.payload))
        #expect(cmpctblock0.header == aliceBlock1.header)

        // … --(cmpctblock)->> Bob
        try await bob.processMessage(messageAB0_cmpctblock, from: peerA)

        // Bob --(cmpctblock)->> …
        let messageBC0_cmpctblock = try #require(await bobToCarol.next())
        #expect(messageBC0_cmpctblock.command == .cmpctblock)

        let cmpctblock1 = try #require(CompactBlockMessage(messageBC0_cmpctblock.payload))
        #expect(cmpctblock1.header == aliceBlock1.header)

        // … --(cmpctblock)->> Carol
        try await carol.processMessage(messageBC0_cmpctblock, from: carolPeerB)

        let bobsHeight0 = await bob.blockchain.headers
        #expect(await alice.blockchain.headers == bobsHeight0)
        #expect(await carol.blockchain.headers == bobsHeight0)

        let aliceTip  = await alice.blockchain.height
        #expect(aliceTip == 1)

        // let pubkey = try #require(PubKey(compressed: [0x03, 0x5a, 0xc9, 0xd1, 0x48, 0x78, 0x68, 0xec, 0xa6, 0x4e, 0x93, 0x2a, 0x06, 0xee, 0x8d, 0x6d, 0x2e, 0x89, 0xd9, 0x86, 0x59, 0xdb, 0x7f, 0x24, 0x74, 0x10, 0xd3, 0xe7, 0x9f, 0x88, 0xf8, 0xd0, 0x05])) // Testnet p2pkh address  miueyHbQ33FDcjCYZpVJdC7VBbaVQzAUg5
        // try await bob.blockchain.processBlock(aliceBlock1)
        // try await carol.blockchain.processBlock(aliceBlock1)

        #expect(await bob.blockchain.height == aliceTip)
        #expect(await carol.blockchain.height == aliceTip)

        // Grab block 1's coinbase transaction and output.
        let coinbaseTx = aliceBlock1.txs[0]

        var tx = Transaction(
            ins: [.init(outpoint: coinbaseTx.outpoint(0))],
            outs: [
                .init(value: 1000, script: .payToPubkeyHash(pubkey))
            ])

        var signer = TransactionSigner(tx: tx, prevouts: [coinbaseTx.outs[0]])
        signer.sign(input: 0, with: secretKey)
        tx = signer.tx

        try await alice.blockchain.addTransaction(tx)

        // Alice --(inv)->> …
        let messageAB1_inv = try #require(await aliceToBob.next())
        #expect(messageAB1_inv.command == .inv)

        let inv0 = try #require(InventoryMessage(messageAB1_inv.payload))
        #expect(inv0.items == [.init(type: .witnessTx, hash: tx.id)])

        // … --(inv)->> Bob
        try await bob.processMessage(messageAB1_inv, from: peerA)

        // Bob --(getdata)->> …
        let messageBA0_getdata = try #require(await bob.popMessage(peerA))
        #expect(messageBA0_getdata.command == .getdata)

        let getData0 = try #require(GetDataMessage(messageBA0_getdata.payload))
        #expect(getData0.items == [.init(type: .witnessTx, hash: tx.id)])

        // … --(getdata)->> Alice
        try await alice.processMessage(messageBA0_getdata, from: peerB)

        // Alice --(tx)->> …
        let messageAB2_tx = try #require(await alice.popMessage(peerB))
        #expect(messageAB2_tx.command == .tx)

        let tx0 = try Transaction(messageAB2_tx.payload)
        #expect(tx0 == tx)

        // … --(tx)->> Bob
        try await bob.processMessage(messageAB2_tx, from: peerA)

        // Bob --(inv)->> …
        let messageBC1_inv = try #require(await bobToCarol.next())
        #expect(messageBC1_inv.command == .inv)

        let inv1 = try #require(InventoryMessage(messageBC1_inv.payload))
        #expect(inv1.items == [.init(type: .witnessTx, hash: tx.id)])

        // … --(inv)->> Carol
        try await carol.processMessage(messageBC1_inv, from: carolPeerB)

        // Carol --(getdata)->> …
        let messageCB0_getdata = try #require(await carol.popMessage(carolPeerB))
        #expect(messageCB0_getdata.command == .getdata)

        let getData1 = try #require(GetDataMessage(messageCB0_getdata.payload))
        #expect(getData1.items == [.init(type: .witnessTx, hash: tx.id)])

        // … --(getdata)->> Bob
        try await bob.processMessage(messageCB0_getdata, from: peerC)

        // Bob --(tx)->> …
        let messageBC2_tx = try #require(await bob.popMessage(peerC))
        #expect(messageBC2_tx.command == .tx)

        let tx1 = try Transaction(messageBC2_tx.payload)
        #expect(tx1 == tx)

        // … --(tx)->> Carol
        try await carol.processMessage(messageBC2_tx, from: carolPeerB)

        #expect(await carol.popMessage(carolPeerB) == nil)

        let bobsMempool = await bob.blockchain.mempool
        #expect(await alice.blockchain.mempool == bobsMempool)
        #expect(await carol.blockchain.mempool == bobsMempool)

        await cleanup([alice, bob, carol])
    }

    @Test("Compact block (high bandwidth mode)")
    func  compactBlockHighBandwidth() async throws {
        // Alices's node
        let peerB = 0
        let alice = await NodeService(
            blockchain: try await .init(params: .swiftTesting),
            config: .init(keepAliveFrequency: nil),
            state: NodeState(peers: [peerB : makePeerState()])
        )

        // Bob's node
        let peerA = 0
        let peerC = 1 // Carol on Bob's node
        let bob = await NodeService(blockchain: try await .init(params: .swiftTesting), config: .init(keepAliveFrequency: nil), state: NodeState(peers: [peerA : makePeerState(true), peerC : makePeerState()]))

        // Carol's node
        let carolPeerB = 0 // Bob on Carol's node
        let carol = await NodeService(blockchain: try await .init(params: .swiftTesting), config: .init(keepAliveFrequency: nil), state: NodeState(peers: [carolPeerB : makePeerState(true)]))

        // Peer channels
        var aliceToBob = await alice.channel(for: peerB).makeAsyncIterator()
        var bobToAlice = await bob.channel(for: peerA).makeAsyncIterator()
        var bobToCarol = await bob.channel(for: peerC).makeAsyncIterator()

        // Begin testing
        let block0 = try #require(await alice.blockchain.generateTo(pubkey))

        // Alice --(cmpctblock)->> …
        let messageAB0_cmpctblock = try #require(await aliceToBob.next())
        #expect(messageAB0_cmpctblock.command == .cmpctblock)

        let cmpctblock0 = try #require(CompactBlockMessage(messageAB0_cmpctblock.payload))
        #expect(cmpctblock0.header == block0.header)

        // … --(cmpctblock)->> Bob
        try await bob.processMessage(messageAB0_cmpctblock, from: peerA)

        // Bob --(cmpctblock)->> …
        let messageBC0_cmpctblock = try #require(await bobToCarol.next())
        #expect(messageBC0_cmpctblock.command == .cmpctblock)

        let cmpctblock1 = try #require(CompactBlockMessage(messageBC0_cmpctblock.payload))
        #expect(cmpctblock1.header == block0.header)

        // … --(cmpctblock)->> Carol
        try await carol.processMessage(messageBC0_cmpctblock, from: carolPeerB)

        let bobsHeight0 = await bob.blockchain.headers
        #expect(await alice.blockchain.headers == bobsHeight0)
        #expect(await carol.blockchain.headers == bobsHeight0)

        let aliceTip  = await alice.blockchain.height
        #expect(aliceTip == 1)

        // Setup blockchains
        let aliceBlock1 = try #require(await alice.blockchain.generateTo(pubkey))

        // Alice --(cmpctblock)->> …
        let messageAB1_cmpctblock = try #require(await aliceToBob.next())
        #expect(messageAB1_cmpctblock.command == .cmpctblock)

        let cmpctblock2 = try #require(CompactBlockMessage(messageAB1_cmpctblock.payload))
        #expect(cmpctblock2.header == aliceBlock1.header)

        // … --(cmpctblock)->> Bob
        try await bob.processMessage(messageAB1_cmpctblock, from: peerA)

        // Bob --(cmpctblock)->> …
        let messageBC1_cmpctblock = try #require(await bobToCarol.next())
        #expect(messageBC1_cmpctblock.command == .cmpctblock)

        let cmpctblock3 = try #require(CompactBlockMessage(messageBC1_cmpctblock.payload))
        #expect(cmpctblock3.header == aliceBlock1.header)

        // … --(cmpctblock)->> Carol
        try await carol.processMessage(messageBC1_cmpctblock, from: carolPeerB)

        let bobsHeight1 = await bob.blockchain.headers
        #expect(await alice.blockchain.headers == bobsHeight1)
        #expect(await carol.blockchain.headers == bobsHeight1)

        let aliceTip2  = await alice.blockchain.height
        #expect(aliceTip2 == 2)

        // Grab block 1's coinbase transaction and output.
        let coinbaseTx = aliceBlock1.txs[0]

        var tx = Transaction(
            ins: [.init(outpoint: coinbaseTx.outpoint(0))],
            outs: [
                .init(value: 1000, script: .payToPubkeyHash(pubkey))
            ])

        var signer = TransactionSigner(tx: tx, prevouts: [coinbaseTx.outs[0]])
        signer.sign(input: 0, with: secretKey)
        tx = signer.tx

        try await alice.blockchain.addTransaction(tx)

        // Alice --(inv)->> …
        let messageAB2_inv = try #require(await aliceToBob.next())
        #expect(messageAB2_inv.command == .inv)

        let inv0 = try #require(InventoryMessage(messageAB2_inv.payload))
        #expect(inv0.items == [.init(type: .witnessTx, hash: tx.id)])

        // … --(inv)->> Bob
        // try await bob.processMessage(messageAB2_inv, from: peerA)
        try await bob.blockchain.addTransaction(tx)

        // Bob --(inv)->> …
        let messageBA0_inv = try #require(await bobToAlice.next())
        #expect(messageBA0_inv.command == .inv)

        let inv1 = try #require(InventoryMessage(messageBA0_inv.payload))
        #expect(inv1.items == [.init(type: .witnessTx, hash: tx.id)])

        let messageBC2_inv = try #require(await bobToCarol.next())
        #expect(messageBC2_inv.command == .inv)

        let inv2 = try #require(InventoryMessage(messageBC2_inv.payload))
        #expect(inv2.items == [.init(type: .witnessTx, hash: tx.id)])

        // … --(inv)->> Carol
        // Carol will not have a copy of the transaction therefore will have to request it
        // try await bob.processMessage(messageAB2_inv, from: peerA)
        // try await carol.blockchain.addTransaction(tx)

        let aliceBlock2 = try #require(await alice.blockchain.generateTo(pubkey))

        // Alice --(cmpctblock)->> …
        let messageAB3_cmpctblock = try #require(await aliceToBob.next())
        #expect(messageAB3_cmpctblock.command == .cmpctblock)

        let cmpctblock4 = try #require(CompactBlockMessage(messageAB3_cmpctblock.payload))
        #expect(cmpctblock4.header == aliceBlock2.header)

        // … --(cmpctblock)->> Bob
        try await bob.processMessage(messageAB3_cmpctblock, from: peerA)

        // Bob --(cmpctblock)->> …
        let messageBC3_cmpctblock = try #require(await bobToCarol.next())
        #expect(messageBC3_cmpctblock.command == .cmpctblock)

        let cmpctblock5 = try #require(CompactBlockMessage(messageBC3_cmpctblock.payload))
        #expect(cmpctblock5.header == aliceBlock2.header)

        // … --(cmpctblock)->> Carol
        try await carol.processMessage(messageBC3_cmpctblock, from: carolPeerB)

        // Carol --(getblocktxn)->> …
        let messageCB0_getblocktxn = try #require(await carol.popMessage(carolPeerB))
        #expect(messageCB0_getblocktxn.command == .getblocktxn)

        let getblocktxn0 = try #require(GetBlockTransactionsMessage(messageCB0_getblocktxn.payload))
        #expect(getblocktxn0.blockHash == aliceBlock2.id)
        #expect(getblocktxn0.txIndices == [1])

        // … --(getblocktxn)->> Bob
        try await bob.processMessage(messageCB0_getblocktxn, from: peerC)

        // Bob --(blocktxn)->> …
        let messageBC4_blocktxn = try #require(await bob.popMessage(peerC))
        #expect(messageBC4_blocktxn.command == .blocktxn)

        let blocktxn0 = try #require(BlockTransactionsMessage(messageBC4_blocktxn.payload))
        #expect(blocktxn0.txs == [tx])

        // … --(blocktxn)->> Carol
        try await carol.processMessage(messageBC4_blocktxn, from: carolPeerB)

        #expect(await carol.popMessage(carolPeerB) == nil)

        let bobsHeight = await bob.blockchain.headers
        #expect(await alice.blockchain.headers == bobsHeight)
        #expect(await carol.blockchain.headers == bobsHeight)

        await cleanup([alice, bob, carol])
    }

    @Test("Compact block (low bandwidth mode)") func compactBlockLowBandwidth() async throws {
        // Alices's node
        let peerB = 0
        let alice = await NodeService(
            blockchain: try await .init(params: .swiftTesting),
            config: .init(keepAliveFrequency: nil),
            state: NodeState(peers: [peerB : makePeerState(highBandwidth: false)])
        )

        // Bob's node
        let peerA = 0
        let peerC = 1 // Carol on Bob's node
        let bob = await NodeService(blockchain: try await .init(params: .swiftTesting), config: .init(keepAliveFrequency: nil), state: NodeState(peers: [peerA : makePeerState(true), peerC : makePeerState(highBandwidth: false)]))

        // Carol's node
        let carolPeerB = 0 // Bob on Carol's node
        let carol = await NodeService(blockchain: try await .init(params: .swiftTesting), config: .init(keepAliveFrequency: nil), state: NodeState(peers: [carolPeerB : makePeerState(true)]))

        // Peer channels
        var aliceToBob = await alice.channel(for: peerB).makeAsyncIterator()
        var bobToAlice = await bob.channel(for: peerA).makeAsyncIterator()
        var bobToCarol = await bob.channel(for: peerC).makeAsyncIterator()

        // Begin testing

        // Setup blockchains
        let block0 = try #require(await alice.blockchain.generateTo(pubkey))

        // Alice --(headers)->> …
        let messageAB0_headers = try #require(await aliceToBob.next())
        #expect(messageAB0_headers.command == .headers)

        let headers0 = try #require(HeadersMessage(messageAB0_headers.payload))
        #expect(headers0.items == [block0.header])

        // … --(headers)->> Bob
        try await bob.processMessage(messageAB0_headers, from: peerA)

        // Bob --(sendheaders)->> …
        let messageBA0_sendheaders = try #require(await bob.popMessage(peerA))
        #expect(messageBA0_sendheaders.command == .sendheaders)

        // … --(sendheaders)->> Alice
        try await alice.processMessage(messageBA0_sendheaders, from: peerB)

        // Bob --(getdata)->> …
        let messageBA1_getdata = try #require(await bob.popMessage(peerA))
        #expect(messageBA1_getdata.command == .getdata)

        let getData0 = try #require(GetDataMessage(messageBA1_getdata.payload))
        #expect(getData0.items == [.init(type: .witnessBlock, hash: block0.id)])

        // … --(getdata)->> Alice
        try await alice.processMessage(messageBA1_getdata, from: peerB)
        // Alice --(block)->> …
        let messageAB1_block = try #require(await alice.popMessage(peerB))

        #expect(messageAB1_block.command == .block)

        let block = try Block(messageAB1_block.payload)
        #expect(block.header == block0.header)

        // … --(block)->> Bob
        try await bob.processMessage(messageAB1_block, from: peerA)

        // Bob --(headers)->> …
        let messageBC0_headers = try #require(await bobToCarol.next())
        #expect(messageBC0_headers.command == .headers)

        let headers1 = try #require(HeadersMessage(messageBC0_headers.payload))
        #expect(headers1.items == [block0.header])

        // … --(headers)->> Carol
        try await carol.processMessage(messageBC0_headers, from: carolPeerB)

        // Carol --(sendheaders)->> …
        let messageCB0_sendheaders = try #require(await carol.popMessage(carolPeerB))
        #expect(messageCB0_sendheaders.command == .sendheaders)

        // … --(sendheaders)->> Bob
        try await bob.processMessage(messageCB0_sendheaders, from: peerC)

        // Carol --(getdata)->> …
        let messageCB1_getdata = try #require(await carol.popMessage(carolPeerB))
        #expect(messageCB1_getdata.command == .getdata)

        let getData1 = try #require(GetDataMessage(messageCB1_getdata.payload))
        #expect(getData1.items == [.init(type: .witnessBlock, hash: block0.id)])

        // … --(getdata)->> Bob
        try await bob.processMessage(messageCB1_getdata, from: peerC)

        // Bob --(block)->> …
        let messageBC1_block = try #require(await bob.popMessage(peerC))
        #expect(messageBC1_block.command == .block)

        let block1 = try Block(messageBC1_block.payload)
        #expect(block1.header == block0.header)

        // … --(block)->> Carol
        try await carol.processMessage(messageBC1_block, from: carolPeerB)

        let bobsHeight0 = await bob.blockchain.headers
        #expect(await alice.blockchain.headers == bobsHeight0)
        #expect(await carol.blockchain.headers == bobsHeight0)

        let aliceTip  = await alice.blockchain.height
        #expect(aliceTip == 1)

        // Setup blockchains
        let aliceBlock1 = try #require(await alice.blockchain.generateTo(pubkey))

        // Alice --(headers)->> …
        let messageAB2_headers = try #require(await aliceToBob.next())
        #expect(messageAB2_headers.command == .headers)

        let headers2 = try #require(HeadersMessage(messageAB2_headers.payload))
        #expect(headers2.items == [aliceBlock1.header])

        // … --(headers)->> Bob
        try await bob.processMessage(messageAB2_headers, from: peerA)

        // Bob --(sendheaders)->> …
        let messageBA2_sendheaders = try #require(await bob.popMessage(peerA))
        #expect(messageBA2_sendheaders.command == .sendheaders)

        // … --(sendheaders)->> Alice
        try await alice.processMessage(messageBA2_sendheaders, from: peerB)

        // Bob --(getdata)->> …
        let messageBA3_getdata = try #require(await bob.popMessage(peerA))
        #expect(messageBA3_getdata.command == .getdata)

        let getData2 = try #require(GetDataMessage(messageBA3_getdata.payload))
        #expect(getData2.items == [.init(type: .compactBlock, hash: aliceBlock1.id)])

        // … --(getdata)->> Alice
        try await alice.processMessage(messageBA3_getdata, from: peerB)

        // Alice --(block)->> …
        let messageAB3_cmpctblock = try #require(await alice.popMessage(peerB))

        #expect(messageAB3_cmpctblock.command == .cmpctblock)

        let cmpctblock0 = try #require(CompactBlockMessage(messageAB3_cmpctblock.payload))
        #expect(cmpctblock0.header == aliceBlock1.header)

        // … --(cmpctblock)->> Bob
        try await bob.processMessage(messageAB3_cmpctblock, from: peerA)

        // Bob --(headers)->> …
        let messageBC2_headers = try #require(await bobToCarol.next())
        #expect(messageBC2_headers.command == .headers)

        let headers3 = try #require(HeadersMessage(messageBC2_headers.payload))
        #expect(headers3.items == [aliceBlock1.header])

        // … --(headers)->> Carol
        try await carol.processMessage(messageBC2_headers, from: carolPeerB)

        // Carol --(sendheaders)->> …
        let messageCB2_sendheaders = try #require(await carol.popMessage(carolPeerB))
        #expect(messageCB2_sendheaders.command == .sendheaders)

        // … --(sendheaders)->> Bob
        try await bob.processMessage(messageCB2_sendheaders, from: peerC)

        // Carol --(getdata)->> …
        let messageCB3_getdata = try #require(await carol.popMessage(carolPeerB))
        #expect(messageCB3_getdata.command == .getdata)

        let getData3 = try #require(GetDataMessage(messageCB3_getdata.payload))
        #expect(getData3.items == [.init(type: .compactBlock, hash: aliceBlock1.id)])

        // … --(getdata)->> Bob
        try await bob.processMessage(messageCB3_getdata, from: peerC)

        // Bob --(cmpctblock)->> …
        let messageBC3_cmpctblock = try #require(await bob.popMessage(peerC))
        #expect(messageBC3_cmpctblock.command == .cmpctblock)

        let cmpctblock1 = try #require(CompactBlockMessage(messageBC3_cmpctblock.payload))
        #expect(cmpctblock1.header == aliceBlock1.header)

        // … --(cmpctblock)->> Carol
        try await carol.processMessage(messageBC3_cmpctblock, from: carolPeerB)

        let bobsHeight1 = await bob.blockchain.headers
        #expect(await alice.blockchain.headers == bobsHeight1)
        #expect(await carol.blockchain.headers == bobsHeight1)

        let aliceTip2  = await alice.blockchain.height
        #expect(aliceTip2 == 2)

        let bobsHeight2 = await bob.blockchain.headers
        #expect(await alice.blockchain.headers == bobsHeight2)
        #expect(await carol.blockchain.headers == bobsHeight2)

        // Grab block 1's coinbase transaction and output.
        let coinbaseTx = aliceBlock1.txs[0]

        var tx = Transaction(
            ins: [.init(outpoint: coinbaseTx.outpoint(0))],
            outs: [
                .init(value: 1000, script: .payToPubkeyHash(pubkey))
            ])

        var signer = TransactionSigner(tx: tx, prevouts: [coinbaseTx.outs[0]])
        signer.sign(input: 0, with: secretKey)
        tx = signer.tx

        try await alice.blockchain.addTransaction(tx)

        // Alice --(inv)->> …
        let messageAB4_inv = try #require(await aliceToBob.next())
        #expect(messageAB4_inv.command == .inv)

        let inv4 = try #require(InventoryMessage(messageAB4_inv.payload))
        #expect(inv4.items == [.init(type: .witnessTx, hash: tx.id)])

        // … --(inv)->> Bob
        // try await bob.processMessage(messageAB4_inv, from: peerA)
        try await bob.blockchain.addTransaction(tx) // Shortcut

        // Bob --(inv)->> …
        let messageBA5_inv = try #require(await bobToAlice.next())
        #expect(messageBA5_inv.command == .inv)

        let inv5 = try #require(InventoryMessage(messageBA5_inv.payload))
        #expect(inv5.items == [.init(type: .witnessTx, hash: tx.id)])

        let messageBC5_inv = try #require(await bobToCarol.next())
        #expect(messageBC5_inv.command == .inv)

        let inv6 = try #require(InventoryMessage(messageBC5_inv.payload))
        #expect(inv6.items == [.init(type: .witnessTx, hash: tx.id)])

        // … --(inv)->> Carol
        // Carol will not have a copy of the transaction therefore will have to request it
        // try await bob.processMessage(messageBC5_inv, from: peerA)

        let aliceBlock2 = try #require(await alice.blockchain.generateTo(pubkey))

        #expect(await alice.blockchain.headers == 3)
        #expect(await alice.blockchain.height == 3)

        // Alice --(headers)->> …
        let messageAB5_headers = try #require(await aliceToBob.next())
        #expect(messageAB5_headers.command == .headers)

        let headers4 = try #require(HeadersMessage(messageAB5_headers.payload))
        #expect(headers4.items == [aliceBlock2.header])

        // … --(header)->> Bob
        try await bob.processMessage(messageAB5_headers, from: peerA)
        #expect(await bob.blockchain.headers == 3)
        #expect(await bob.blockchain.height == 2)

        // Bob --(sendheaders)->> …
        let messageBA6_sendheaders = try #require(await bob.popMessage(peerA))
        #expect(messageBA6_sendheaders.command == .sendheaders)

        // … --(sendheaders)->> Alice
        try await alice.processMessage(messageBA6_sendheaders, from: peerB)

        // Bob --(getdata)->> …
        let messageBA7_getdata = try #require(await bob.popMessage(peerA))
        #expect(messageBA7_getdata.command == .getdata)

        let getData4 = try #require(GetDataMessage(messageBA7_getdata.payload))
        #expect(getData4.items == [.init(type: .compactBlock, hash: aliceBlock2.id)])

        // … --(getdata)->> Alice
        try await alice.processMessage(messageBA7_getdata, from: peerB)

        // Alice --(cmpctblock)->> …
        let messageAB6_cmpctblock = try #require(await alice.popMessage(peerB))
        #expect(messageAB6_cmpctblock.command == .cmpctblock)

        let cmpctblock6 = try #require(CompactBlockMessage(messageAB6_cmpctblock.payload))
        #expect(cmpctblock6.header == aliceBlock2.header)

        // … --(cmpctblock)->> Bob
        try await bob.processMessage(messageAB6_cmpctblock, from: peerA)
        #expect(await bob.blockchain.headers == 3)
        #expect(await bob.blockchain.height == 3)

        // Bob --(headers)->> …
        let messageBC6_headers = try #require(await bobToCarol.next())
        #expect(messageBC6_headers.command == .headers)

        let headers5 = try #require(HeadersMessage(messageBC6_headers.payload))
        #expect(headers5.items == [aliceBlock2.header])

        // … --(headers)->> Carol
        try await carol.processMessage(messageBC6_headers, from: carolPeerB)

        // Carol --(sendheaders)->> …
        let messageCB6_sendheaders = try #require(await carol.popMessage(carolPeerB))
        #expect(messageCB6_sendheaders.command == .sendheaders)

        // … --(sendheaders)->> Bob
        try await bob.processMessage(messageCB6_sendheaders, from: peerC)

        // Carol --(getdata)->> …
        let messageCB7_getdata = try #require(await carol.popMessage(carolPeerB))
        #expect(messageCB7_getdata.command == .getdata)

        let getData5 = try #require(GetDataMessage(messageCB7_getdata.payload))
        #expect(getData5.items == [.init(type: .compactBlock, hash: aliceBlock2.id)])

        // … --(getdata)->> Bob
        try await bob.processMessage(messageCB7_getdata, from: peerC)

        // Bob --(cmpctblock)->> …
        let messageBC7_cmpctblock = try #require(await bob.popMessage(peerC))
        #expect(messageBC7_cmpctblock.command == .cmpctblock)

        let cmpctblock7 = try #require(CompactBlockMessage(messageBC7_cmpctblock.payload))
        #expect(cmpctblock7.header == aliceBlock2.header)

        // … --(cmpctblock)->> Carol
        try await carol.processMessage(messageBC7_cmpctblock, from: carolPeerB)

        // Carol --(getblocktxn)->> …
        let messageCB8_getblocktxn = try #require(await carol.popMessage(carolPeerB))
        #expect(messageCB8_getblocktxn.command == .getblocktxn)

        let getblocktxn1 = try #require(GetBlockTransactionsMessage(messageCB8_getblocktxn.payload))
        #expect(getblocktxn1.blockHash == aliceBlock2.id)
        #expect(getblocktxn1.txIndices == [1])

        // … --(getblocktxn)->> Bob
        try await bob.processMessage(messageCB8_getblocktxn, from: peerC)

        // Bob --(blocktxn)->> …
        let messageBC8_blocktxn = try #require(await bob.popMessage(peerC))
        #expect(messageBC8_blocktxn.command == .blocktxn)

        let blocktxn1 = try #require(BlockTransactionsMessage(messageBC8_blocktxn.payload))
        #expect(blocktxn1.txs == [tx])

        // … --(blocktxn)->> Carol
        try await carol.processMessage(messageBC8_blocktxn, from: carolPeerB)

        #expect(await carol.popMessage(carolPeerB) == nil)

        let bobsHeight = await bob.blockchain.headers
        #expect(await alice.blockchain.headers == bobsHeight)
        #expect(await carol.blockchain.headers == bobsHeight)

        await cleanup([alice, bob, carol])
    }
}

private func cleanup(_ services: [NodeService]) async {
    for s in services {
        for p in await s.state.peers.keys {
            await s.removePeer(p)
        }
        await s.blockchain.shutdown()
    }
}

private func makePeerState(_ incoming: Bool = false, highBandwidth: Bool = true) -> PeerState {
    var ps = PeerState(address: IPv6Address.unspecified, host: "", port: 0, incoming: incoming)
    ps.version = .init()
    ps.witnessRelayPreferenceReceived = true
    ps.v2AddressPreferenceReceived = true
    ps.versionAckReceived = true
    ps.compactBlocksVersion = 2
    ps.compactBlocksPreferenceSent = true
    ps.compactBlocksVersionLocked = true
    ps.highBandwidthCompactBlocks = highBandwidth
    ps.prefersHeaders = true
    ps.allHeadersDownloaded = true
    return ps
}
