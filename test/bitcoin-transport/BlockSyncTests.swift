import Testing
import BitcoinCrypto
import Foundation
import AsyncAlgorithms
import BitcoinBlockchain
@testable import BitcoinTransport

struct BlockSyncTests {

    var aliceChain = BlockchainService?.none
    var alice = NodeService?.none
    var peerB = PeerID?.none
    var aliceToBob = AsyncChannel<NetworkMessage>.Iterator?.none

    var bobChain = BlockchainService?.none
    var bob = NodeService?.none
    var peerA = PeerID?.none
    var bobToAlice = AsyncChannel<NetworkMessage>.Iterator?.none

    init() async throws {
        var params = ConsensusParams.swiftTesting

        // 3 blocks to IBD completion
        params.minChainwork = [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x06]

        let aliceChain = try await BlockchainService(params: params)
        self.aliceChain = aliceChain
        let alice = NodeService(blockchain: aliceChain, config: .init(network: .regtest, maxInTransitBlocks: 2, feeFilterRate: 3))
        Task {
            await alice.start()
        }
        self.alice = alice
        let peerB = await alice.addPeer(incoming: false)
        self.peerB = peerB
        bobToAlice = await alice.getChannel(for: peerB).makeAsyncIterator()

        let bobChain = try await BlockchainService(params: .swiftTesting)
        let pubkey = try #require(PublicKey(compressed: [0x03, 0x5a, 0xc9, 0xd1, 0x48, 0x78, 0x68, 0xec, 0xa6, 0x4e, 0x93, 0x2a, 0x06, 0xee, 0x8d, 0x6d, 0x2e, 0x89, 0xd9, 0x86, 0x59, 0xdb, 0x7f, 0x24, 0x74, 0x10, 0xd3, 0xe7, 0x9f, 0x88, 0xf8, 0xd0, 0x05])) // Testnet p2pkh address  miueyHbQ33FDcjCYZpVJdC7VBbaVQzAUg5
        await bobChain.generateTo(pubkey)
        await bobChain.generateTo(pubkey)
        await bobChain.generateTo(pubkey)

        self.bobChain = bobChain
        let bob = NodeService(blockchain: bobChain, config: .init(network: .regtest, maxInTransitBlocks: 2, feeFilterRate: 3))
        self.bob = bob
        let peerA = await bob.addPeer()
        self.peerA = peerA
        aliceToBob = await bob.getChannel(for: peerA).makeAsyncIterator()
    }

    func cleanUp() async throws {
        if let peerB, let alice {
            await alice.removePeer(peerB)
        }
        if let alice, let aliceChain {
            await alice.stop()
            await aliceChain.unsubscribeAll()
        }
        if let peerA, let bob {
            await bob.removePeer(peerA)
        }
        if let bob, let bobChain {
            await bob.stop()
            await bobChain.unsubscribeAll()
        }
    }

    /// Tests handshake and extended post-handshake exchange.
    ///
    /// Alice's node (initiating):
    ///
    ///     -> version
    ///     -> wtxidrelay
    ///     -> sendaddrv2
    ///     <- version
    ///     <- wtxidrelay
    ///     <- sendaddrv2
    ///     <- verack
    ///     -> verack
    ///     -> sendcmpct
    ///     -> ping
    ///     -> feefilter
    ///     <- sendcmpct
    ///     <- ping
    ///     -> pong
    ///     <- feefilter
    ///     <- pong
    ///
    /// Bob's node (recipient):
    ///
    ///     <- version
    ///     <- wtxidrelay
    ///     <- sendaddrv2
    ///     -> version
    ///     -> wtxidrelay … (same as initiating)
    ///
    /// Outbound connection sequence (bitcoin core):
    ///
    ///     -> version (we send the first message)
    ///     -> wtxidrelay
    ///     -> sendaddrv2
    ///     <- version
    ///     -> verack
    ///     -> getaddr
    ///     <- verack
    ///     -> sendcmpct
    ///     -> ping
    ///     -> getheaders
    ///     -> feefilter
    ///     <- pong
    ///
    func handshake() async throws {

        guard let alice, let peerB, let aliceChain, let bob, let peerA, let bobChain else { preconditionFailure() }

        await alice.connect(peerB)

        // `mAB0` means "0th Message from Alice to Bob".

        // Alice --(version)->> …
        // Alice --(wtxidrelay)->> …
        // Alice --(sendaddrv2)->> …
        let mAB0_version = try #require(await alice.popMessage(peerB))
        #expect(mAB0_version.command == .version)

        let mAB1_wtxidrelay = try #require(await alice.popMessage(peerB))
        #expect(mAB1_wtxidrelay.command == .wtxidrelay)

        let mAB2_sendaddrv2 = try #require(await alice.popMessage(peerB))
        #expect(mAB2_sendaddrv2.command == .sendaddrv2)

        // … --(version)->> Bob
        // … --(wtxidrelay)->> Bob
        // … --(sendaddrv2)->> Bob
        try await bob.processMessage(mAB0_version, from: peerA)
        try await bob.processMessage(mAB1_wtxidrelay, from: peerA)
        try await bob.processMessage(mAB2_sendaddrv2, from: peerA)

        // Bob --(version)->> …
        // Bob --(wtxidrelay)->> …
        // Bob --(sendaddrv2)->> …
        // Bob --(verack)->> …
        let mBA0_version = try #require(await bob.popMessage(peerA))
        #expect(mBA0_version.command == .version)

        let mBA1_wtxidrelay = try #require(await bob.popMessage(peerA))
        #expect(mBA1_wtxidrelay.command == .wtxidrelay)

        let mBA2_sendaddrv2 = try #require(await bob.popMessage(peerA))
        #expect(mBA2_sendaddrv2.command == .sendaddrv2)

        let mBA3_verack = try #require(await bob.popMessage(peerA))
        #expect(mBA3_verack.command == .verack)

        // … --(version)->> Alice
        // … --(wtxidrelay)->> Alice
        // … --(sendaddrv2)->> Alice
        // … --(verack)->> Alice
        try await alice.processMessage(mBA0_version, from: peerB)
        try await alice.processMessage(mBA1_wtxidrelay, from: peerB)
        try await alice.processMessage(mBA2_sendaddrv2, from: peerB)
        try await alice.processMessage(mBA3_verack, from: peerB)

        // Alice --(verack)->> …
        // Alice --(sendcmpct)->> …
        // Alice --(ping)->> …
        // Alice --(getheaders)->> …
        // Alice --(feefilter)->> …
        let mAB3_verack = try #require(await alice.popMessage(peerB))
        #expect(mAB3_verack.command == .verack)

        let mAB4_sendcmpct = try #require(await alice.popMessage(peerB))
        #expect(mAB4_sendcmpct.command == .sendcmpct)

        let mAB5_ping = try #require(await alice.popMessage(peerB))
        #expect(mAB5_ping.command == .ping)

        let mAB6_getheaders = try #require(await alice.popMessage(peerB))
        #expect(mAB6_getheaders.command == .getheaders)

        let aliceGetHeaders = try #require(GetHeadersMessage(mAB6_getheaders.payload))
        #expect(aliceGetHeaders.locatorHashes.count == 1)

        let mAB7_feefilter = try #require(await alice.popMessage(peerB))
        #expect(mAB7_feefilter.command == .feefilter)

        // … --(verack)->> Bob
        try await bob.processMessage(mAB3_verack, from: peerA)

        // Bob --(sendcmpct)->> …
        // Bob --(ping)->> …
        // Bob --(getheaders)->> …
        // Bob --(feefilter)->> …
        let mBA4_sendcmpct = try #require(await bob.popMessage(peerA))
        #expect(mBA4_sendcmpct.command == .sendcmpct)

        let mBA5_ping = try #require(await bob.popMessage(peerA))
        #expect(mBA5_ping.command == .ping)

        let mBA6_getheaders = try #require(await bob.popMessage(peerA))
        #expect(mBA6_getheaders.command == .getheaders)

        let bobGetHeaders = try #require(GetHeadersMessage(mBA6_getheaders.payload))
        #expect(bobGetHeaders.locatorHashes.count == 4)

        let mBA7_feefilter = try #require(await bob.popMessage(peerA))
        #expect(mBA7_feefilter.command == .feefilter)

        // … --(sendcmpct)->> Bob
        // … --(ping)->> Bob
        try await bob.processMessage(mAB4_sendcmpct, from: peerA) // No response expected
        try await bob.processMessage(mAB5_ping, from: peerA)

        // Bob --(pong)->> …
        let mBA8_pong = try #require(await bob.popMessage(peerA))
        #expect(mBA8_pong.command == .pong)

        // … --(getheaders)->> Bob
        try await bob.processMessage(mAB6_getheaders, from: peerA)

        // Bob --(headers)->> …
        let mBA9_headers = try #require(await bob.popMessage(peerA))
        #expect(mBA9_headers.command == .headers)

        let bobHeaders = try #require(HeadersMessage(mBA9_headers.payload))
        #expect(bobHeaders.items.count == 3)
        await #expect(aliceChain.genesisBlock.id == bobHeaders.items[0].previous)
        #expect(bobHeaders.items[0].id == bobHeaders.items[1].previous)

        // … --(feefilter)->> Bob
        try await bob.processMessage(mAB7_feefilter, from: peerA) // No response expected

        // … --(sendcmpct)->> Alice
        // … --(ping)->> Alice
        try await alice.processMessage(mBA4_sendcmpct, from: peerB) // No response expected
        try await alice.processMessage(mBA5_ping, from: peerB)

        // Alice --(pong)->> …
        let mAB8_pong = try #require(await alice.popMessage(peerB))
        #expect(mAB8_pong.command == .pong)

        // … --(getheaders)->> Alice
        try await alice.processMessage(mBA6_getheaders, from: peerB)

        // Alice --(headers)->> …
        let mAB9_headers = try #require(await alice.popMessage(peerB))
        #expect(mAB9_headers.command == .headers)

        let aliceHeaders = try #require(HeadersMessage(mAB9_headers.payload))
        #expect(aliceHeaders.items.count == 0)

        // … --(feefilter)->> Alice
        // … --(pong)->> Alice
        // … --(headers)->> Alice
        try await alice.processMessage(mBA7_feefilter, from: peerB) // No response expected
        try await alice.processMessage(mBA8_pong, from: peerB) // No response expected
        try await alice.processMessage(mBA9_headers, from: peerB)

        try await #require(aliceChain.headers == 3)

        // Alice --(sendheaders)->> …
        let mAB10_sendheaders = try #require(await alice.popMessage(peerB))
        #expect(mAB10_sendheaders.command == .sendheaders)

        // Alice --(getdata)->> …
        let mAB11_getdata = try #require(await alice.popMessage(peerB))
        #expect(mAB11_getdata.command == .getdata)

        let aliceGetData = try #require(GetDataMessage(mAB11_getdata.payload))
        #expect(aliceGetData.items.count == 2)

        // … --(pong)->> Bob
        try await bob.processMessage(mAB8_pong, from: peerA)

        // No Response
        #expect(await bob.popMessage(peerA) == nil)

        let bobHeadersBefore = await bobChain.headers + 1

        // … --(headers)->> Bob
        try await bob.processMessage(mAB9_headers, from: peerA)

        let bobHeadersAfter = await bobChain.headers + 1
        #expect(bobHeadersAfter == bobHeadersBefore)

        // Bob --(sendheaders)->> …
        let mBA10_sendheaders = try #require(await bob.popMessage(peerA))
        #expect(mBA10_sendheaders.command == .sendheaders)

        // No Response
        #expect(await bob.popMessage(peerA) == nil)

        // … --(sendheaders)->> Bob
        try await bob.processMessage(mAB10_sendheaders, from: peerA)

        // … --(getdata)->> Bob
        try await bob.processMessage(mAB11_getdata, from: peerA)

        // Bob --(block)->> …
        let mBA11_block = try #require(await bob.popMessage(peerA))
        #expect(mBA11_block.command == .block)

        let bobBlock1 = try Block(mBA11_block.payload)
        #expect(bobBlock1.txs.count == 1)

        // Bob --(block)->> …
        let mBA12_block = try #require(await bob.popMessage(peerA))
        #expect(mBA12_block.command == .block)

        let bobBlock2 = try Block(mBA12_block.payload)
        #expect(bobBlock2.txs.count == 1)

        // No Response
        #expect(await bob.popMessage(peerA) == nil)

        await #expect(aliceChain.height == 0)

        // … --(sendheaders)->> Alice
        // … --(block)->> Alice
        // … --(block)->> Alice
        try await alice.processMessage(mBA10_sendheaders, from: peerB)

        let blockUpdates = await alice.subscribeToBlocks()

        var task = Task {
            var i = blockUpdates.makeAsyncIterator()
            return await i.next()
        }
        try await alice.processMessage(mBA11_block, from: peerB)
        _ = try #require(await task.value)
        #expect(await aliceChain.height == 1)

        task = Task {
            var i = blockUpdates.makeAsyncIterator()
            return await i.next()
        }
        try await alice.processMessage(mBA12_block, from: peerB)
        _ = try #require(await task.value)

        #expect(await aliceChain.height == 2)

        // Alice --(getdata)->> …
        let mAB12_getdata = try #require(await alice.popMessage(peerB))
        #expect(mAB12_getdata.command == .getdata)

        let aliceGetData1 = try #require(GetDataMessage(mAB12_getdata.payload))
        #expect(aliceGetData1.items.count == 1)

        // … --(getdata)->> Bob
        try await bob.processMessage(mAB12_getdata, from: peerA)

        // Bob --(block)->> …
        let mBA13_block = try #require(await bob.popMessage(peerA))
        #expect(mBA13_block.command == .block)

        let bobBlock3 = try Block(mBA13_block.payload)
        #expect(bobBlock3.txs.count == 1)

        // … --(block)->> Alice
        task = Task {
            var i = blockUpdates.makeAsyncIterator()
            return await i.next()
        }
        try await alice.processMessage(mBA13_block, from: peerB)
        _ = try #require(await task.value)
        #expect(await aliceChain.height == 3)

        // No Response
        #expect(await alice.popMessage(peerB) == nil)
    }

    /// Extended handshake.
    @Test("Initial Block Download")
    func initialBlockDownload() async throws {
        try await handshake()
        try await cleanUp()
    }
}
