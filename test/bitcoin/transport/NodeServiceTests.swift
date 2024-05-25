import XCTest
import AsyncAlgorithms
@testable import Bitcoin

final class NodeServiceTests: XCTestCase {

    var satoshiChain = BitcoinService?.none
    var satoshi = NodeService?.none
    var halPeer = UUID?.none
    var satoshiOut = AsyncChannel<BitcoinMessage>.Iterator?.none

    var halChain = BitcoinService?.none
    var hal = NodeService?.none
    var satoshiPeer = UUID?.none
    var halOut = AsyncChannel<BitcoinMessage>.Iterator?.none

    override class func setUp() {
        super.setUp()
    }

    override func setUp() async throws {
        let satoshiChain = BitcoinService()
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

    override func tearDown() async throws {
        if let halPeer {
            await satoshi?.removePeer(halPeer)
        }
        try await satoshi?.stop()
        await satoshiChain?.shutdown()
        halPeer = .none
        satoshi = .none
        satoshiChain = .none

        if let satoshiPeer {
            await hal?.removePeer(satoshiPeer)
        }
        try await hal?.stop()
        await halChain?.shutdown()
        hal = .none
        halChain = .none
    }

    /// Tests handshake and extended post-handshake exchange.
    ///
    /// Outbound connection sequence:
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

        guard let satoshi, let halPeer, var satoshiOut, let hal, let satoshiPeer, var halOut else { preconditionFailure() }

        // Hal --(version)->> …
        Task {
            await hal.connect(satoshiPeer)
        }
        // `messageHS0` means "0th Message from Hal to Satoshi".
        guard let messageHS0_version = await halOut.next() else { XCTFail(); return }
        await Task.yield()
        XCTAssertEqual(messageHS0_version.command, .version)

        // … --(version)->> Satoshi
        Task {
            try await satoshi.processMessage(messageHS0_version, from: halPeer)
        }
        // Satoshi --(version)->> …
        guard let messageSH0_version = await satoshiOut.next() else { XCTFail(); return }
        await Task.yield()
        XCTAssertEqual(messageSH0_version.command, .version)

        // Satoshi --(wtxidrelay)->> …
        guard let messageSH1_wtxidrelay = await satoshiOut.next() else { XCTFail(); return }
        await Task.yield()
        XCTAssertEqual(messageSH1_wtxidrelay.command, .wtxidrelay)

        // Satoshi --(sendaddrv2)->> …
        guard let messageSH2_sendaddrv2 = await satoshiOut.next() else { XCTFail(); return }
        await Task.yield()
        XCTAssertEqual(messageSH2_sendaddrv2.command, .sendaddrv2)

        // Satoshi --(verack)->> …
        guard let messageSH3_verack = await satoshiOut.next() else { XCTFail(); return }
        await Task.yield()
        XCTAssertEqual(messageSH3_verack.command, .verack)

        // … --(version)->> Hal
        Task {
            try await hal.processMessage(messageSH0_version, from: satoshiPeer)
        }
        // Hal --(wtxidrelay)->> …
        guard let messageHS1_wtxidrelay = await halOut.next() else { XCTFail(); return }
        await Task.yield()
        XCTAssertEqual(messageHS1_wtxidrelay.command, .wtxidrelay)

        // Hal --(sendaddrv2)->> …
        guard let messageHS2_sendaddrv2 = await halOut.next() else { XCTFail(); return }
        await Task.yield()
        XCTAssertEqual(messageHS2_sendaddrv2.command, .sendaddrv2)

        // Hal --(verack)->> …
        guard let messageHS3_verack = await halOut.next() else { XCTFail(); return }
        await Task.yield()
        XCTAssertEqual(messageHS3_verack.command, .verack)

        let versionReceived = await hal.peers[satoshiPeer]!.version
        XCTAssertNotNil(versionReceived)

        // … --(wtxidrelay)->> Hal
        try await hal.processMessage(messageSH1_wtxidrelay, from: satoshiPeer)
        var wtxidRelay = await hal.peers[satoshiPeer]!.witnessRelayPreferenceReceived
        XCTAssert(wtxidRelay)

        // … --(sendaddrv2)->> Hal
        try await hal.processMessage(messageSH2_sendaddrv2, from: satoshiPeer)
        var v2Addr = await hal.peers[satoshiPeer]!.v2AddressPreferenceReceived
        XCTAssert(v2Addr)

        // … --(verack)->> Hal
        Task {
            try await hal.processMessage(messageSH3_verack, from: satoshiPeer)
        }
        // Hal --(sendcmpct)->> …
        guard let messageHS4_sendcmpct = await halOut.next() else { XCTFail(); return }
        await Task.yield()
        XCTAssertEqual(messageHS4_sendcmpct.command, .sendcmpct)

        // Hal --(ping)->> …
        guard let messageHS5_ping = await halOut.next() else { XCTFail(); return }
        await Task.yield()
        XCTAssertEqual(messageHS5_ping.command, .ping)

        // Hal --(feefilter)->> …
        guard let messageHS6_feefilter = await halOut.next() else { XCTFail(); return }
        await Task.yield()
        XCTAssertEqual(messageHS6_feefilter.command, .feefilter)

        let halFeeRate1 = try XCTUnwrap(FeeFilterMessage(messageHS6_feefilter.payload))
        let halFeeRate = await hal.feeFilterRate
        XCTAssertEqual(halFeeRate1.feeRate, halFeeRate)

        var veracked = await hal.peers[satoshiPeer]!.versionAckReceived
        XCTAssert(veracked)

        var handshook = await hal.peers[satoshiPeer]!.handshakeComplete
        XCTAssert(handshook)

        // … --(wtxidrelay)->> Satoshi
        try await satoshi.processMessage(messageHS1_wtxidrelay, from: halPeer)
        wtxidRelay = await satoshi.peers[halPeer]!.witnessRelayPreferenceReceived
        XCTAssert(wtxidRelay)

        // … --(sendaddrv2)->> Satoshi
        try await satoshi.processMessage(messageHS2_sendaddrv2, from: halPeer)
        v2Addr = await satoshi.peers[halPeer]!.v2AddressPreferenceReceived
        XCTAssert(v2Addr)

        // … --(verack)->> Satoshi
        Task {
            try await satoshi.processMessage(messageHS3_verack, from: halPeer)
        }
        // Satoshi --(sendcmpct)->> …
        guard let messageSH4_sendcmpct = await satoshiOut.next() else { XCTFail(); return }
        await Task.yield()
        XCTAssertEqual(messageSH4_sendcmpct.command, .sendcmpct)

        // Satoshi --(ping)->> …
        guard let messageSH5_ping = await satoshiOut.next() else { XCTFail(); return }
        await Task.yield()
        XCTAssertEqual(messageSH5_ping.command, .ping)

        // Satoshi --(feefilter)->> …
        guard let messageSH6_feefilter = await satoshiOut.next() else { XCTFail(); return }
        await Task.yield()
        XCTAssertEqual(messageSH6_feefilter.command, .feefilter)

        let satoshiFeeRate1 = try XCTUnwrap(FeeFilterMessage(messageSH6_feefilter.payload))
        let satoshiFeeRate = await satoshi.feeFilterRate
        XCTAssertEqual(satoshiFeeRate1.feeRate, satoshiFeeRate)

        veracked = await satoshi.peers[halPeer]!.versionAckReceived
        XCTAssert(veracked)

        handshook = await satoshi.peers[halPeer]!.handshakeComplete
        XCTAssert(handshook)

        // … --(sendcmpct)->> Satoshi
        try await satoshi.processMessage(messageHS4_sendcmpct, from: halPeer) // No response expected
        let compactBlocksVersionHal = await satoshi.peers[halPeer]!.compactBlocksVersion
        XCTAssertEqual(compactBlocksVersionHal, 2)

        // … --(ping)->> Satoshi
        Task {
            try await satoshi.processMessage(messageHS5_ping, from: halPeer)
        }
        // Satoshi --(pong)->> …
        guard let messageSH7_pong = await satoshiOut.next() else { XCTFail(); return }
        await Task.yield()
        XCTAssertEqual(messageSH7_pong.command, .pong)

        // … --(feefilter)->> Satoshi
        try await satoshi.processMessage(messageHS6_feefilter, from: halPeer) // No response expected
        let halFeeRate2 = await satoshi.peers[halPeer]!.feeFilterRate
        XCTAssertEqual(halFeeRate2, halFeeRate)

        // … --(sendcmpct)->> Hal
        try await hal.processMessage(messageSH4_sendcmpct, from: satoshiPeer) // No response expected
        let compactBlocksVersionSatoshiB = await hal.peers[satoshiPeer]!.compactBlocksVersion
        XCTAssertEqual(compactBlocksVersionSatoshiB, 2)

        // … --(ping)->> Hal
        Task {
            try await hal.processMessage(messageSH5_ping, from: satoshiPeer)
        }
        // Hal --(pong)->> …
        guard let messageHS7_pong = await halOut.next() else { XCTFail(); return }
        await Task.yield()
        XCTAssertEqual(messageHS7_pong.command, .pong)

        // … --(feefilter)->> Hal
        try await hal.processMessage(messageSH6_feefilter, from: satoshiPeer) // No response expected
        let satoshiFeeRate2 = await hal.peers[satoshiPeer]!.feeFilterRate
        XCTAssertEqual(satoshiFeeRate2, satoshiFeeRate)

        // … --(pong)->> Hal
        try await hal.processMessage(messageSH7_pong, from: satoshiPeer) // No response expected

        let compactBlocksVersionLockedHal = await hal.peers[satoshiPeer]!.compactBlocksVersionLocked
        XCTAssert(compactBlocksVersionLockedHal)

        // … --(pong)->> Satoshi
        try await satoshi.processMessage(messageHS7_pong, from: halPeer) // No response expected
        let compactBlocksVersionLockedSatoshi = await satoshi.peers[halPeer]!.compactBlocksVersionLocked
        XCTAssert(compactBlocksVersionLockedSatoshi)
    }

    func testHandshake() async throws {
        try await performExtendedHandshake()
    }

    func testPingPong() async throws {
        try await performExtendedHandshake()

        guard let satoshi, let halPeer, var satoshiOut, let hal, let satoshiPeer, var halOut else { preconditionFailure() }

        Task {
            await hal.sendPingTo(satoshiPeer)
        }
        // Hal --(ping)->> …
        guard let messageHS0_ping = await halOut.next() else { XCTFail(); return }
        await Task.yield()
        XCTAssertEqual(messageHS0_ping.command, .ping)

        let ping = try XCTUnwrap(PingMessage(messageHS0_ping.payload))
        var lastPingNonce = await hal.peers[satoshiPeer]!.lastPingNonce
        XCTAssertNotNil(lastPingNonce)

        // … --(ping)->> Satoshi
        Task {
            try await satoshi.processMessage(messageHS0_ping, from: halPeer)
        }
        // Satoshi --(pong)->> …
        guard let messageSH0_pong = await satoshiOut.next() else { XCTFail(); return }
        await Task.yield()
        XCTAssertEqual(messageSH0_pong.command, .pong)

        let pong = try XCTUnwrap(PongMessage(messageSH0_pong.payload))
        XCTAssertEqual(ping.nonce, pong.nonce)

        // … --(pong)->> Hal
        try await hal.processMessage(messageSH0_pong, from: satoshiPeer) // No response expected

        lastPingNonce = await hal.peers[satoshiPeer]!.lastPingNonce
        XCTAssertNil(lastPingNonce)
    }
}
