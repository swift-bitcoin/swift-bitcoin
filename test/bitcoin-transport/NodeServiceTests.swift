import Testing
import BitcoinCrypto
import Foundation
import AsyncAlgorithms
import BitcoinBlockchain
@testable import BitcoinTransport

final class NodeServiceTests {

    var satoshiChain = BitcoinService?.none
    var satoshi = NodeService?.none
    var halPeer = UUID?.none
    var satoshiOut = AsyncChannel<BitcoinMessage>.Iterator?.none

    var halChain = BitcoinService?.none
    var hal = NodeService?.none
    var satoshiPeer = UUID?.none
    var halOut = AsyncChannel<BitcoinMessage>.Iterator?.none

    init() async throws {
        let satoshiChain = BitcoinService()
        let publicKey = try #require(PublicKey(compressed: [0x03, 0x5a, 0xc9, 0xd1, 0x48, 0x78, 0x68, 0xec, 0xa6, 0x4e, 0x93, 0x2a, 0x06, 0xee, 0x8d, 0x6d, 0x2e, 0x89, 0xd9, 0x86, 0x59, 0xdb, 0x7f, 0x24, 0x74, 0x10, 0xd3, 0xe7, 0x9f, 0x88, 0xf8, 0xd0, 0x05])) // Testnet p2pkh address  miueyHbQ33FDcjCYZpVJdC7VBbaVQzAUg5
        await satoshiChain.generateTo(publicKey)

        self.satoshiChain = satoshiChain
        let satoshi = NodeService(bitcoinService: satoshiChain, feeFilterRate: 2)
        self.satoshi = satoshi
        let halPeer = await satoshi.addPeer()
        self.halPeer = halPeer
        satoshiOut = await satoshi.getChannel(for: halPeer).makeAsyncIterator()

        let halChain = BitcoinService()
        self.halChain = halChain
        let hal = NodeService(bitcoinService: halChain, feeFilterRate: 3)
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
                try await satoshi.stop()
                await satoshiChain.shutdown()
            }
        }
        // halPeer = .none
        // satoshi = .none
        // satoshiChain = .none

        if let satoshiPeer, let hal {
            Task {
                await hal.removePeer(satoshiPeer)
            }
        }
        if let hal, let halChain {
            Task {
                try await hal.stop()
                await halChain.shutdown()
            }
        }
        // hal = .none
        // halChain = .none
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

        guard let satoshi, let halPeer, let hal, let satoshiPeer else { preconditionFailure() }

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
        var wtxidRelay = await satoshi.peers[halPeer]!.witnessRelayPreferenceReceived
        #expect(wtxidRelay)

        // … --(sendaddrv2)->> Satoshi
        try await satoshi.processMessage(messageHS2_sendaddrv2, from: halPeer)
        var v2Addr = await satoshi.peers[halPeer]!.v2AddressPreferenceReceived
        #expect(v2Addr)

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

        let versionReceived = await hal.peers[satoshiPeer]!.version
        #expect(versionReceived != nil)

        // … --(wtxidrelay)->> Hal
        try await hal.processMessage(messageSH1_wtxidrelay, from: satoshiPeer)
        wtxidRelay = await hal.peers[satoshiPeer]!.witnessRelayPreferenceReceived
        #expect(wtxidRelay)

        // … --(sendaddrv2)->> Hal
        try await hal.processMessage(messageSH2_sendaddrv2, from: satoshiPeer)
        v2Addr = await hal.peers[satoshiPeer]!.v2AddressPreferenceReceived
        #expect(v2Addr)

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

        // Hal --(feefilter)->> …
        let messageHS6_feefilter = try #require(await hal.popMessage(satoshiPeer))
        #expect(messageHS6_feefilter.command == .feefilter)

        let halFeeRate1 = try #require(FeeFilterMessage(messageHS6_feefilter.payload))
        let halFeeRate = await hal.feeFilterRate
        #expect(halFeeRate1.feeRate == halFeeRate)

        var veracked = await hal.peers[satoshiPeer]!.versionAckReceived
        #expect(veracked)

        var handshook = await hal.peers[satoshiPeer]!.handshakeComplete
        #expect(handshook)

        // … --(verack)->> Satoshi
        try await satoshi.processMessage(messageHS3_verack, from: halPeer)
        // Satoshi --(sendcmpct)->> …
        let messageSH4_sendcmpct = try #require(await satoshi.popMessage(halPeer))
        #expect(messageSH4_sendcmpct.command == .sendcmpct)

        // Satoshi --(ping)->> …
        let messageSH5_ping = try #require(await satoshi.popMessage(halPeer))
        #expect(messageSH5_ping.command == .ping)

        // Satoshi --(feefilter)->> …
        let messageSH6_feefilter = try #require(await satoshi.popMessage(halPeer))
        #expect(messageSH6_feefilter.command == .feefilter)

        let satoshiFeeRate1 = try #require(FeeFilterMessage(messageSH6_feefilter.payload))
        let satoshiFeeRate = await satoshi.feeFilterRate
        #expect(satoshiFeeRate1.feeRate == satoshiFeeRate)

        veracked = await satoshi.peers[halPeer]!.versionAckReceived
        #expect(veracked)

        handshook = await satoshi.peers[halPeer]!.handshakeComplete
        #expect(handshook)

        // … --(sendcmpct)->> Satoshi
        try await satoshi.processMessage(messageHS4_sendcmpct, from: halPeer) // No response expected
        let compactBlocksVersionHal = await satoshi.peers[halPeer]!.compactBlocksVersion
        #expect(compactBlocksVersionHal == 2)

        // … --(ping)->> Satoshi
        try await satoshi.processMessage(messageHS5_ping, from: halPeer)
        // Satoshi --(pong)->> …
        let messageSH7_pong = try #require(await satoshi.popMessage(halPeer))
        #expect(messageSH7_pong.command == .pong)

        // … --(feefilter)->> Satoshi
        try await satoshi.processMessage(messageHS6_feefilter, from: halPeer) // No response expected
        let halFeeRate2 = await satoshi.peers[halPeer]!.feeFilterRate
        #expect(halFeeRate2 == halFeeRate)

        // … --(sendcmpct)->> Hal
        try await hal.processMessage(messageSH4_sendcmpct, from: satoshiPeer) // No response expected
        let compactBlocksVersionSatoshiB = await hal.peers[satoshiPeer]!.compactBlocksVersion
        #expect(compactBlocksVersionSatoshiB == 2)

        // … --(ping)->> Hal
        try await hal.processMessage(messageSH5_ping, from: satoshiPeer)
        // Hal --(pong)->> …
        let messageHS7_pong = try #require(await hal.popMessage(satoshiPeer))
        #expect(messageHS7_pong.command == .pong)

        // … --(feefilter)->> Hal
        try await hal.processMessage(messageSH6_feefilter, from: satoshiPeer) // No response expected
        let satoshiFeeRate2 = await hal.peers[satoshiPeer]!.feeFilterRate
        #expect(satoshiFeeRate2 == satoshiFeeRate)

        // … --(pong)->> Hal
        try await hal.processMessage(messageSH7_pong, from: satoshiPeer) // No response expected

        let compactBlocksVersionLockedHal = await hal.peers[satoshiPeer]!.compactBlocksVersionLocked
        #expect(compactBlocksVersionLockedHal)

        // … --(pong)->> Satoshi
        try await satoshi.processMessage(messageHS7_pong, from: halPeer) // No response expected
        let compactBlocksVersionLockedSatoshi = await satoshi.peers[halPeer]!.compactBlocksVersionLocked
        #expect(compactBlocksVersionLockedSatoshi)
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

        let messageHS0_verack = BitcoinMessage(.verack)
        await #expect(throws: NodeService.Error.versionMissing) {
            try await satoshi.processMessage(messageHS0_verack, from: halPeer)
        }
    }

    /// An exception is thrown as `verack` is received before `wtxidrelay` and `sendaddrv2`.
    @Test
    func prematureVerAck() async throws {
        guard let satoshi, let halPeer else { preconditionFailure() }

        // … --(version)->> Satoshi
        let messageHS0_version = BitcoinMessage(.version, payload: VersionMessage().data)

        try await satoshi.processMessage(messageHS0_version, from: halPeer)

        // Satoshi --(version)->> …
        _ = try #require(await satoshi.popMessage(halPeer))

        // Satoshi --(wtxidrelay)->> …
        _ = try #require(await satoshi.popMessage(halPeer))

        // Satoshi --(sendaddrv2)->> …
        _ = try #require(await satoshi.popMessage(halPeer))

        let messageHS1_verack = BitcoinMessage(.verack)
        await #expect(throws: NodeService.Error.missingWTXIDRelayPreference) {
            try await satoshi.processMessage(messageHS1_verack, from: halPeer)
        }
    }

    /// An exception is thrown as `verack` is received  after `wtxidrelay` but before `sendaddrv2`.
    @Test
    func prematureVerAck2() async throws {
        guard let satoshi, let halPeer else { preconditionFailure() }

        // … --(version)->> Satoshi
        let messageHS0_version = BitcoinMessage(.version, payload: VersionMessage().data)

        try await satoshi.processMessage(messageHS0_version, from: halPeer)

        // Satoshi --(version)->> …
        _ = try #require(await satoshi.popMessage(halPeer))

        // Satoshi --(wtxidrelay)->> …
        _ = try #require(await satoshi.popMessage(halPeer))

        // Satoshi --(sendaddrv2)->> …
        _ = try #require(await satoshi.popMessage(halPeer))

        let messageHS1_wtxidrelay = BitcoinMessage(.wtxidrelay)
        try await satoshi.processMessage(messageHS1_wtxidrelay, from: halPeer)

        let messageHS2_verack = BitcoinMessage(.verack)
        await #expect(throws: NodeService.Error.missingV2AddrPreference) {
            try await satoshi.processMessage(messageHS2_verack, from: halPeer)
        }
    }

    /// An exception is thrown as `verack` is received  after `sendaddrv2` but before `wtxidrelay`.
    @Test
    func prematureVerAck3() async throws {
        guard let satoshi, let halPeer else { preconditionFailure() }

        // … --(version)->> Satoshi
        let messageHS0_version = BitcoinMessage(.version, payload: VersionMessage().data)

        try await satoshi.processMessage(messageHS0_version, from: halPeer)

        // Satoshi --(version)->> …
        _ = try #require(await satoshi.popMessage(halPeer))

        // Satoshi --(wtxidrelay)->> …
        _ = try #require(await satoshi.popMessage(halPeer))

        // Satoshi --(sendaddrv2)->> …
        _ = try #require(await satoshi.popMessage(halPeer))

        let messageHS1_sendaddrv2 = BitcoinMessage(.sendaddrv2)
        try await satoshi.processMessage(messageHS1_sendaddrv2, from: halPeer)

        let messageHS2_verack = BitcoinMessage(.verack)
        await #expect(throws: NodeService.Error.missingWTXIDRelayPreference) {
            try await satoshi.processMessage(messageHS2_verack, from: halPeer)
        }
    }

    /// Basic handshake but with `sendaddrv2` received _before_ `wtxidrelay`.
    @Test
    func alternateHandshake() async throws {
        guard let satoshi, let halPeer else { preconditionFailure() }

        // … --(version)->> Satoshi
        let messageHS0_version = BitcoinMessage(.version, payload: VersionMessage().data)

        try await satoshi.processMessage(messageHS0_version, from: halPeer)

        // Satoshi --(version)->> …
        _ = try #require(await satoshi.popMessage(halPeer))

        // Satoshi --(wtxidrelay)->> …
        _ = try #require(await satoshi.popMessage(halPeer))

        // Satoshi --(sendaddrv2)->> …
        _ = try #require(await satoshi.popMessage(halPeer))

        let messageHS1_sendaddrv2 = BitcoinMessage(.sendaddrv2)
        try await satoshi.processMessage(messageHS1_sendaddrv2, from: halPeer)

        let messageHS2_wtxidrelay = BitcoinMessage(.wtxidrelay)
        try await satoshi.processMessage(messageHS2_wtxidrelay, from: halPeer)

        // Satoshi --(verack)->> …
        _ = try #require(await satoshi.popMessage(halPeer))

        let messageHS3_verack = BitcoinMessage(.verack)
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
        var lastPingNonce = await hal.peers[satoshiPeer]!.lastPingNonce
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

        lastPingNonce = await hal.peers[satoshiPeer]!.lastPingNonce
        #expect(lastPingNonce == nil)
    }

    @Test
    func headers() async throws {
        try await performExtendedHandshake()

        guard let satoshi, let halPeer, var satoshiOut, let hal, let satoshiPeer, var halOut else { preconditionFailure() }

        Task {
            await hal.requestHeaders()
        }
        // Hal --(getheaders)->> …
        let messageHS0_getheaders = try #require(await halOut.next())
        await Task.yield()
        #expect(messageHS0_getheaders.command == .getheaders)

        let headersRequest = try #require(GetHeadersMessage(messageHS0_getheaders.payload))
        var receivedHeaders = await hal.peers[satoshiPeer]!.receivedHeaders
        #expect(headersRequest.locatorHashes.count == 1)
        #expect(receivedHeaders == nil)

        // … --(getheaders)->> Satoshi
        Task {
            try await satoshi.processMessage(messageHS0_getheaders, from: halPeer)
        }

        // Satoshi --(headers)->> …
        let messageSH0_headers = try #require(await satoshiOut.next())
        await Task.yield()
        #expect(messageSH0_headers.command == .headers)

        let headersResponse = try #require(HeadersMessage(messageSH0_headers.payload))
        #expect(headersResponse.items.count == 1)

        // … --(headers)->> Hal
        Task {
            try await hal.processMessage(messageSH0_headers, from: satoshiPeer)
        }
        // Hal --(getheaders)->> …
        let messageHS1_header = try #require(await halOut.next())
        await Task.yield()
        #expect(messageHS1_header.command == .getheaders)

        receivedHeaders = await hal.peers[satoshiPeer]!.receivedHeaders
        #expect(receivedHeaders != nil)
        #expect(receivedHeaders!.count == 1)
    }
}
