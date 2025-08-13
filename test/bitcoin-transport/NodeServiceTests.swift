import Testing
import BitcoinCrypto
import Foundation
import AsyncAlgorithms
import BitcoinBlockchain
@testable import BitcoinTransport

struct NodeServiceTests: ~Copyable {

    var satoshiChain = BlockchainService?.none
    var satoshi = NodeService?.none
    var halPeer = UUID?.none
    var satoshiOut = AsyncChannel<NetworkMessage>.Iterator?.none

    var halChain = BlockchainService?.none
    var hal = NodeService?.none
    var satoshiPeer = UUID?.none
    var halOut = AsyncChannel<NetworkMessage>.Iterator?.none

    init() async throws {
        let satoshiChain = BlockchainService()
        await satoshiChain.start()
        let pubkey = try #require(PublicKey(compressed: [0x03, 0x5a, 0xc9, 0xd1, 0x48, 0x78, 0x68, 0xec, 0xa6, 0x4e, 0x93, 0x2a, 0x06, 0xee, 0x8d, 0x6d, 0x2e, 0x89, 0xd9, 0x86, 0x59, 0xdb, 0x7f, 0x24, 0x74, 0x10, 0xd3, 0xe7, 0x9f, 0x88, 0xf8, 0xd0, 0x05])) // Testnet p2pkh address  miueyHbQ33FDcjCYZpVJdC7VBbaVQzAUg5
        await satoshiChain.generateTo(pubkey)

        self.satoshiChain = satoshiChain
        let satoshi = NodeService(blockchain: satoshiChain, config: .init(network: .regtest, feeFilterRate: 2))
        self.satoshi = satoshi
        let halPeer = await satoshi.addPeer()
        self.halPeer = halPeer
        satoshiOut = await satoshi.getChannel(for: halPeer).makeAsyncIterator()

        let halChain = BlockchainService()
        await halChain.start()
        self.halChain = halChain
        let hal = NodeService(blockchain: halChain, config: .init(network: .regtest, feeFilterRate: 2))
        Task {
            await hal.start()
        }
        self.hal = hal
        let satoshiPeer = await hal.addPeer(incoming: false)
        self.satoshiPeer = satoshiPeer
        halOut = await hal.getChannel(for: satoshiPeer).makeAsyncIterator()
    }

    deinit {
        if let halPeer, let satoshi {
            Task {
                await satoshi.removePeer(halPeer)
            }
        }
        if let satoshi, let satoshiChain {
            Task {
                await satoshi.stop()
                await satoshiChain.stop()
            }
        }
        if let satoshiPeer, let hal {
            Task {
                await hal.removePeer(satoshiPeer)
            }
        }
        if let hal, let halChain {
            Task {
                await hal.stop()
                await halChain.stop()
            }
        }
    }

    /// Tests handshake and extended post-handshake exchange.
    ///
    /// Hal's node (initiating):
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
    /// Satoshi's node (recipient):
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
    func performExtendedHandshake() async throws {

        guard let satoshi, let halPeer, let hal, let satoshiPeer, let satoshiChain, let halChain else { preconditionFailure() }

        await hal.connect(satoshiPeer)

        // `messageHS0` means "0th Message from Hal to Satoshi".

        // Hal --(version)->> …
        let messageHS0_version = try #require(await hal.popMessage(satoshiPeer))
        #expect(messageHS0_version.command == .version)

        // Hal --(wtxidrelay)->> …
        let messageHS1_wtxidrelay = try #require(await hal.popMessage(satoshiPeer))
        #expect(messageHS1_wtxidrelay.command == .wtxidrelay)

        // Hal --(sendaddrv2)->> …
        let messageHS2_sendaddrv2 = try #require(await hal.popMessage(satoshiPeer))
        #expect(messageHS2_sendaddrv2.command == .sendaddrv2)

        // … --(version)->> Satoshi
        try await satoshi.processMessage(messageHS0_version, from: halPeer)

        // … --(wtxidrelay)->> Satoshi
        try await satoshi.processMessage(messageHS1_wtxidrelay, from: halPeer)
        var satoshiState = await satoshi.state
        #expect(satoshiState.peers[halPeer]!.witnessRelayPreferenceReceived)

        // … --(sendaddrv2)->> Satoshi
        try await satoshi.processMessage(messageHS2_sendaddrv2, from: halPeer)
        satoshiState = await satoshi.state
        #expect(satoshiState.peers[halPeer]!.v2AddressPreferenceReceived)

        // Satoshi --(version)->> …
        let messageSH0_version = try #require(await satoshi.popMessage(halPeer))
        #expect(messageSH0_version.command == .version)

        // Satoshi --(wtxidrelay)->> …
        let messageSH1_wtxidrelay = try #require(await satoshi.popMessage(halPeer))
        #expect(messageSH1_wtxidrelay.command == .wtxidrelay)

        // Satoshi --(sendaddrv2)->> …
        let messageSH2_sendaddrv2 = try #require(await satoshi.popMessage(halPeer))
        #expect(messageSH2_sendaddrv2.command == .sendaddrv2)

        // Satoshi --(verack)->> …
        let messageSH3_verack = try #require(await satoshi.popMessage(halPeer))
        #expect(messageSH3_verack.command == .verack)

        // … --(version)->> Hal
        try await hal.processMessage(messageSH0_version, from: satoshiPeer)
        var halState = await hal.state
        #expect(halState.peers[satoshiPeer]!.version != nil)

        // … --(wtxidrelay)->> Hal
        try await hal.processMessage(messageSH1_wtxidrelay, from: satoshiPeer)
        halState = await hal.state
        #expect(halState.peers[satoshiPeer]!.witnessRelayPreferenceReceived)

        // … --(sendaddrv2)->> Hal
        try await hal.processMessage(messageSH2_sendaddrv2, from: satoshiPeer)
        halState = await hal.state
        #expect(halState.peers[satoshiPeer]!.v2AddressPreferenceReceived)

        // … --(verack)->> Hal
        try await hal.processMessage(messageSH3_verack, from: satoshiPeer)

        // Hal --(verack)->> …
        let messageHS3_verack = try #require(await hal.popMessage(satoshiPeer))
        #expect(messageHS3_verack.command == .verack)

        // Hal --(sendcmpct)->> …
        let messageHS4_sendcmpct = try #require(await hal.popMessage(satoshiPeer))
        #expect(messageHS4_sendcmpct.command == .sendcmpct)

        // Hal --(ping)->> …
        let messageHS5_ping = try #require(await hal.popMessage(satoshiPeer))
        #expect(messageHS5_ping.command == .ping)

        // Hal --(getheaders)->> …
        let messageHS6_getheaders = try #require(await hal.popMessage(satoshiPeer))
        #expect(messageHS6_getheaders.command == .getheaders)

        let halGetHeaders = try #require(GetHeadersMessage(messageHS6_getheaders.payload))
        #expect(halGetHeaders.locatorHashes.count == 1)

        // Hal --(feefilter)->> …
        let messageHS7_feefilter = try #require(await hal.popMessage(satoshiPeer))
        #expect(messageHS7_feefilter.command == .feefilter)

        let halFeeRate = try #require(FeeFilterMessage(messageHS7_feefilter.payload))
        halState = await hal.state
        #expect(halFeeRate.feeRate == halState.feeFilterRate)
        #expect(halState.peers[satoshiPeer]!.versionAckReceived)
        #expect(halState.peers[satoshiPeer]!.handshakeComplete)

        // … --(verack)->> Satoshi
        try await satoshi.processMessage(messageHS3_verack, from: halPeer)

        // Satoshi --(sendcmpct)->> …
        let messageSH4_sendcmpct = try #require(await satoshi.popMessage(halPeer))
        #expect(messageSH4_sendcmpct.command == .sendcmpct)

        // Satoshi --(ping)->> …
        let messageSH5_ping = try #require(await satoshi.popMessage(halPeer))
        #expect(messageSH5_ping.command == .ping)

        // Satoshi --(getheaders)->> …
        let messageSH6_getheaders = try #require(await satoshi.popMessage(halPeer))
        #expect(messageSH6_getheaders.command == .getheaders)

        let satoshiGetHeaders = try #require(GetHeadersMessage(messageSH6_getheaders.payload))
        #expect(satoshiGetHeaders.locatorHashes.count == 2)

        // Satoshi --(feefilter)->> …
        let messageSH7_feefilter = try #require(await satoshi.popMessage(halPeer))
        #expect(messageSH7_feefilter.command == .feefilter)

        let satoshiFeeRate = try #require(FeeFilterMessage(messageSH7_feefilter.payload))
        satoshiState = await satoshi.state
        #expect(satoshiFeeRate.feeRate == satoshiState.feeFilterRate)
        #expect(satoshiState.peers[halPeer]!.versionAckReceived)
        #expect(satoshiState.peers[halPeer]!.handshakeComplete)

        // … --(sendcmpct)->> Satoshi
        try await satoshi.processMessage(messageHS4_sendcmpct, from: halPeer) // No response expected
        satoshiState = await satoshi.state
        #expect(satoshiState.peers[halPeer]!.compactBlocksVersion == 2)

        // … --(ping)->> Satoshi
        try await satoshi.processMessage(messageHS5_ping, from: halPeer)

        // Satoshi --(pong)->> …
        let messageSH8_pong = try #require(await satoshi.popMessage(halPeer))
        #expect(messageSH8_pong.command == .pong)

        // … --(getheaders)->> Satoshi
        try await satoshi.processMessage(messageHS6_getheaders, from: halPeer)

        // Satoshi --(headers)->> …
        let messageSH9_headers = try #require(await satoshi.popMessage(halPeer))
        #expect(messageSH9_headers.command == .headers)

        let satoshiHeaders = try #require(HeadersMessage(messageSH9_headers.payload))
        #expect(satoshiHeaders.items.count == 1)

        // … --(feefilter)->> Satoshi
        try await satoshi.processMessage(messageHS7_feefilter, from: halPeer) // No response expected
        satoshiState = await satoshi.state
        #expect(satoshiState.peers[halPeer]!.feeFilterRate == halFeeRate.feeRate)

        // … --(sendcmpct)->> Hal
        try await hal.processMessage(messageSH4_sendcmpct, from: satoshiPeer) // No response expected
        halState = await hal.state
        #expect(halState.peers[satoshiPeer]!.compactBlocksVersion == 2)

        // … --(ping)->> Hal
        try await hal.processMessage(messageSH5_ping, from: satoshiPeer)

        // Hal --(pong)->> …
        let messageHS7_pong = try #require(await hal.popMessage(satoshiPeer))
        #expect(messageHS7_pong.command == .pong)

        // … --(getheaders)->> Hal
        try await hal.processMessage(messageSH6_getheaders, from: satoshiPeer)

        // Hal --(headers)->> …
        let messageHS8_headers = try #require(await hal.popMessage(satoshiPeer))
        #expect(messageHS8_headers.command == .headers)

        let halHeaders = try #require(HeadersMessage(messageHS8_headers.payload))
        #expect(halHeaders.items.count == 0)

        // … --(feefilter)->> Hal
        try await hal.processMessage(messageSH7_feefilter, from: satoshiPeer) // No response expected
        halState = await hal.state
        #expect(halState.peers[satoshiPeer]!.feeFilterRate == satoshiFeeRate.feeRate)

        // … --(pong)->> Hal
        try await hal.processMessage(messageSH8_pong, from: satoshiPeer) // No response expected

        halState = await hal.state
        #expect(halState.peers[satoshiPeer]!.compactBlocksVersionLocked)
        await #expect(halChain.height == 0)

        // … --(headers)->> Hal
        try await hal.processMessage(messageSH9_headers, from: satoshiPeer)

        #expect(await halChain.height == 1)

        // Hal --(sendheaders)->> …
        let messageHS09_sendheaders = try #require(await hal.popMessage(satoshiPeer))
        #expect(messageHS09_sendheaders.command == .sendheaders)

        // Hal --(getdata)->> …
        let messageHS10_getdata = try #require(await hal.popMessage(satoshiPeer))
        #expect(messageHS10_getdata.command == .getdata)

        let halGetData = try #require(GetDataMessage(messageHS10_getdata.payload))
        #expect(halGetData.items.count == 1)

        // … --(pong)->> Satoshi
        try await satoshi.processMessage(messageHS7_pong, from: halPeer)

        // No Response
        #expect(await satoshi.popMessage(halPeer) == nil)

        satoshiState = await satoshi.state
        #expect(satoshiState.peers[halPeer]!.compactBlocksVersionLocked)

        let satoshiHeightBefore = await satoshiChain.height

        // … --(headers)->> Satoshi
        try await satoshi.processMessage(messageHS8_headers, from: halPeer)

        let satoshiHeightAfter = await satoshiChain.height
        #expect(satoshiHeightAfter == satoshiHeightBefore)

        // Satoshi --(sendheaders)->> …
        let messageSH10_sendheaders = try #require(await satoshi.popMessage(halPeer))
        #expect(messageSH10_sendheaders.command == .sendheaders)

        // No Response
        #expect(await satoshi.popMessage(halPeer) == nil)

        // … --(sendheaders)->> Satoshi
        try await satoshi.processMessage(messageHS09_sendheaders, from: halPeer)

        // No Response
        #expect(await satoshi.popMessage(halPeer) == nil)

        // … --(getdata)->> Satoshi
        try await satoshi.processMessage(messageHS10_getdata, from: halPeer)

        // Satoshi --(block)->> …
        let messageSH11_block = try #require(await satoshi.popMessage(halPeer))
        #expect(messageSH11_block.command == .block)

        let satoshiBlock = try Block(messageSH11_block.payload)
        #expect(satoshiBlock.txs.count == 1)

        let halBlocksBefore = await halChain.validatedHeight + 1
        #expect(halBlocksBefore == 1)

        // … --(sendheaders)->> Hal
        try await hal.processMessage(messageSH10_sendheaders, from: satoshiPeer)

        // No Response
        #expect(await hal.popMessage(satoshiPeer) == nil)

        // … --(block)->> Hal
        let blockUpdates = await hal.subscribeToBlocks()
        let task = Task {
            var i = blockUpdates.makeAsyncIterator()
            return await i.next()
        }
        try await hal.processMessage(messageSH11_block, from: satoshiPeer)
        _ = try #require(await task.value)

        let halBlocksAfter = await halChain.validatedHeight + 1
        #expect(halBlocksAfter == 2)

        // No Response
        #expect(await hal.popMessage(satoshiPeer) == nil)
    }

    /// Extended handshake.
    @Test("Handshake")
    func handshake() async throws {
        try await performExtendedHandshake()
    }

    /// An exception is thrown as `verack` is received before `version`.
    @Test
    func badInitialMessage() async throws {
        guard let satoshi, let halPeer else { preconditionFailure() }

        let messageHS0_verack = NetworkMessage(.verack)
        await #expect(throws: NodeService.Error.versionMissing) {
            try await satoshi.processMessage(messageHS0_verack, from: halPeer)
        }
    }

    /// An exception is thrown as `verack` is received before `wtxidrelay` and `sendaddrv2`.
    @Test
    func prematureVerAck() async throws {
        guard let satoshi, let halPeer else { preconditionFailure() }

        // … --(version)->> Satoshi
        let messageHS0_version = NetworkMessage(.version, payload: VersionMessage().data)

        try await satoshi.processMessage(messageHS0_version, from: halPeer)

        // Satoshi --(version)->> …
        _ = try #require(await satoshi.popMessage(halPeer))

        // Satoshi --(wtxidrelay)->> …
        _ = try #require(await satoshi.popMessage(halPeer))

        // Satoshi --(sendaddrv2)->> …
        _ = try #require(await satoshi.popMessage(halPeer))

        let messageHS1_verack = NetworkMessage(.verack)
        await #expect(throws: NodeService.Error.missingWTXIDRelayPreference) {
            try await satoshi.processMessage(messageHS1_verack, from: halPeer)
        }
    }

    /// An exception is thrown as `verack` is received  after `wtxidrelay` but before `sendaddrv2`.
    @Test
    func prematureVerAck2() async throws {
        guard let satoshi, let halPeer else { preconditionFailure() }

        // … --(version)->> Satoshi
        let messageHS0_version = NetworkMessage(.version, payload: VersionMessage().data)

        try await satoshi.processMessage(messageHS0_version, from: halPeer)

        // Satoshi --(version)->> …
        _ = try #require(await satoshi.popMessage(halPeer))

        // Satoshi --(wtxidrelay)->> …
        _ = try #require(await satoshi.popMessage(halPeer))

        // Satoshi --(sendaddrv2)->> …
        _ = try #require(await satoshi.popMessage(halPeer))

        let messageHS1_wtxidrelay = NetworkMessage(.wtxidrelay)
        try await satoshi.processMessage(messageHS1_wtxidrelay, from: halPeer)

        let messageHS2_verack = NetworkMessage(.verack)
        await #expect(throws: NodeService.Error.missingV2AddrPreference) {
            try await satoshi.processMessage(messageHS2_verack, from: halPeer)
        }
    }

    /// An exception is thrown as `verack` is received  after `sendaddrv2` but before `wtxidrelay`.
    @Test
    func prematureVerAck3() async throws {
        guard let satoshi, let halPeer else { preconditionFailure() }

        // … --(version)->> Satoshi
        let messageHS0_version = NetworkMessage(.version, payload: VersionMessage().data)

        try await satoshi.processMessage(messageHS0_version, from: halPeer)

        // Satoshi --(version)->> …
        _ = try #require(await satoshi.popMessage(halPeer))

        // Satoshi --(wtxidrelay)->> …
        _ = try #require(await satoshi.popMessage(halPeer))

        // Satoshi --(sendaddrv2)->> …
        _ = try #require(await satoshi.popMessage(halPeer))

        let messageHS1_sendaddrv2 = NetworkMessage(.sendaddrv2)
        try await satoshi.processMessage(messageHS1_sendaddrv2, from: halPeer)

        let messageHS2_verack = NetworkMessage(.verack)
        await #expect(throws: NodeService.Error.missingWTXIDRelayPreference) {
            try await satoshi.processMessage(messageHS2_verack, from: halPeer)
        }
    }

    /// Basic handshake but with `sendaddrv2` received _before_ `wtxidrelay`.
    @Test
    func alternateHandshake() async throws {
        guard let satoshi, let halPeer else { preconditionFailure() }

        // … --(version)->> Satoshi
        let messageHS0_version = NetworkMessage(.version, payload: VersionMessage().data)

        try await satoshi.processMessage(messageHS0_version, from: halPeer)

        // Satoshi --(version)->> …
        _ = try #require(await satoshi.popMessage(halPeer))

        // Satoshi --(wtxidrelay)->> …
        _ = try #require(await satoshi.popMessage(halPeer))

        // Satoshi --(sendaddrv2)->> …
        _ = try #require(await satoshi.popMessage(halPeer))

        let messageHS1_sendaddrv2 = NetworkMessage(.sendaddrv2)
        try await satoshi.processMessage(messageHS1_sendaddrv2, from: halPeer)

        let messageHS2_wtxidrelay = NetworkMessage(.wtxidrelay)
        try await satoshi.processMessage(messageHS2_wtxidrelay, from: halPeer)

        // Satoshi --(verack)->> …
        _ = try #require(await satoshi.popMessage(halPeer))

        let messageHS3_verack = NetworkMessage(.verack)
        try await satoshi.processMessage(messageHS3_verack, from: halPeer)

        // Satoshi --(sendcmpct)->> …
        _ = try #require(await satoshi.popMessage(halPeer))

        // Satoshi --(ping)->> …
        _ = try #require(await satoshi.popMessage(halPeer))

        // Satoshi --(feefilter)->> …
        _ = try #require(await satoshi.popMessage(halPeer))
    }

    /// Checks that a valid `pong` response is produced after receiving `ping`.
    @Test
    func pingPong() async throws {
        try await performExtendedHandshake()

        guard let satoshi, let halPeer, let hal, let satoshiPeer, var halOut else { preconditionFailure() }

        Task {
            await hal.sendPingTo(satoshiPeer)
        }
        // Hal --(ping)->> …
        let messageHS0_ping = try #require(await halOut.next())
        await Task.yield()
        #expect(messageHS0_ping.command == .ping)

        let ping = try #require(PingMessage(messageHS0_ping.payload))
        var lastPingNonce = await hal.state.peers[satoshiPeer]!.lastPingNonce
        #expect(lastPingNonce != nil)

        // … --(ping)->> Satoshi
        try await satoshi.processMessage(messageHS0_ping, from: halPeer)
        // Satoshi --(pong)->> …
        let messageSH0_pong = try #require(await satoshi.popMessage(halPeer))
        #expect(messageSH0_pong.command == .pong)

        let pong = try #require(PongMessage(messageSH0_pong.payload))
        #expect(ping.nonce == pong.nonce)

        // … --(pong)->> Hal
        try await hal.processMessage(messageSH0_pong, from: satoshiPeer) // No response expected

        lastPingNonce = await hal.state.peers[satoshiPeer]!.lastPingNonce
        #expect(lastPingNonce == nil)
    }
}
