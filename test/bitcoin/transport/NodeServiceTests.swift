import XCTest
@testable import Bitcoin

final class NodeServiceTests: XCTestCase {

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
    func testExtendedHandshake() async throws {
        let serviceA = BitcoinService()
        let serviceB = BitcoinService()
        let serverNode = NodeService(bitcoinService: serviceA, feeFilterRate: 2)
        let clientNode = NodeService(bitcoinService: serviceB, feeFilterRate: 3)
        let peerInServer = await serverNode.addPeer(host: "", port: 0)
        let peerInClient = await clientNode.addPeer(host: "", port: 0, incoming: false)
        var serverMessages = await serverNode.getChannel(for: peerInServer).makeAsyncIterator()
        var clientMessages = await clientNode.getChannel(for: peerInClient).makeAsyncIterator()

        // Client --(version)->> …
        Task {
            await clientNode.connect(peerInClient)
        }
        guard let clientVersion = await clientMessages.next() else { XCTFail(); return }
        await Task.yield()
        XCTAssertEqual(clientVersion.command, .version)

        // … --(version)->> Server
        Task {
            try await serverNode.processMessage(clientVersion, from: peerInServer)
        }
        // … <<-(version)-- Server
        guard let serverVersion = await serverMessages.next() else { XCTFail(); return }
        await Task.yield()
        XCTAssertEqual(serverVersion.command, .version)

        // … <<-(wtxidrelay)-- Server
        guard let serverWTXIDRelay = await serverMessages.next() else { XCTFail(); return }
        await Task.yield()
        XCTAssertEqual(serverWTXIDRelay.command, .wtxidrelay)

        // … <<-(sendaddrv2)-- Server
        guard let serverSendAddrV2 = await serverMessages.next() else { XCTFail(); return }
        await Task.yield()
        XCTAssertEqual(serverSendAddrV2.command, .sendaddrv2)

        // … <<-(verack)-- Server
        guard let serverVerack = await serverMessages.next() else { XCTFail(); return }
        await Task.yield()
        XCTAssertEqual(serverVerack.command, .verack)

        // Client <<-(version)-- …
        Task {
            try await clientNode.processMessage(serverVersion, from: peerInClient)
        }
        // Client --(wtxidrelay)->> …
        guard let clientWTXIDRelay = await clientMessages.next() else { XCTFail(); return }
        await Task.yield()
        XCTAssertEqual(clientWTXIDRelay.command, .wtxidrelay)

        // Client --(sendaddrv2)->> …
        guard let clientSendAddrV2 = await clientMessages.next() else { XCTFail(); return }
        await Task.yield()
        XCTAssertEqual(clientSendAddrV2.command, .sendaddrv2)

        // Client --(verack)->> …
        guard let clientVerack = await clientMessages.next() else { XCTFail(); return }
        await Task.yield()
        XCTAssertEqual(clientVerack.command, .verack)

        let versionReceived = await clientNode.peers[peerInClient]!.receivedVersion
        XCTAssert(versionReceived)

        // Client <<-(wtxidrelay)-- …
        try await clientNode.processMessage(serverWTXIDRelay, from: peerInClient)
        var wtxidRelay = await clientNode.peers[peerInClient]!.receivedWTXIDRelayPreference
        XCTAssert(wtxidRelay)

        // Client <<-(sendaddrv2)-- …
        try await clientNode.processMessage(serverSendAddrV2, from: peerInClient)
        var v2Addr = await clientNode.peers[peerInClient]!.receivedV2AddressPreference
        XCTAssert(v2Addr)

        // Client <<-(verack)-- …
        Task {
            try await clientNode.processMessage(serverVerack, from: peerInClient)
        }
        // Client --(sendcmpct)->> …
        guard let clientSendCompactMessage = await clientMessages.next() else { XCTFail(); return }
        await Task.yield()
        XCTAssertEqual(clientSendCompactMessage.command, .sendcmpct)

        // Client --(ping)->> …
        guard let clientPingMessage = await clientMessages.next() else { XCTFail(); return }
        await Task.yield()
        XCTAssertEqual(clientPingMessage.command, .ping)

        let ping = try XCTUnwrap(PingMessage(clientPingMessage.payload))
        var lastPingNonce = await clientNode.peers[peerInClient]!.lastPingNonce
        XCTAssertNotNil(lastPingNonce)

        // Client --(feefilter)->> …
        guard let clientFeeFilterMessage = await clientMessages.next() else { XCTFail(); return }
        await Task.yield()
        XCTAssertEqual(clientFeeFilterMessage.command, .feefilter)

        let clientFeeFilter = try XCTUnwrap(FeeFilterMessage(clientFeeFilterMessage.payload))
        let clientFeeRate = await clientNode.feeFilterRate
        XCTAssertEqual(clientFeeFilter.feeRate, clientFeeRate)

        var veracked = await clientNode.peers[peerInClient]!.receivedVersionAck
        XCTAssert(veracked)
        var handshook = await clientNode.peers[peerInClient]!.handshakeComplete
        XCTAssert(handshook)

        // … --(wtxidrelay)->> Server
        try await serverNode.processMessage(clientWTXIDRelay, from: peerInServer)
        wtxidRelay = await serverNode.peers[peerInServer]!.receivedWTXIDRelayPreference
        XCTAssert(wtxidRelay)

        // … --(sendaddrv2)->> Server
        try await serverNode.processMessage(clientSendAddrV2, from: peerInServer)
        v2Addr = await serverNode.peers[peerInServer]!.receivedV2AddressPreference
        XCTAssert(v2Addr)

        // … --(verack)->> Server
        Task {
            try await serverNode.processMessage(clientVerack, from: peerInServer)
        }
        // … <<-(sendcmpct)-- Server
        guard let serverSendCompactMessage = await serverMessages.next() else { XCTFail(); return }
        await Task.yield()
        XCTAssertEqual(serverSendCompactMessage.command, .sendcmpct)

        // … <<-(ping)-- Server
        guard let serverPingMessage = await serverMessages.next() else { XCTFail(); return }
        await Task.yield()
        XCTAssertEqual(serverPingMessage.command, .ping)

        // … <<-(feefilter)-- Server
        guard let serverFeeFilterMessage = await serverMessages.next() else { XCTFail(); return }
        await Task.yield()
        XCTAssertEqual(serverFeeFilterMessage.command, .feefilter)

        let serverFeeFilter = try XCTUnwrap(FeeFilterMessage(serverFeeFilterMessage.payload))
        let serverFeeRate = await serverNode.feeFilterRate
        XCTAssertEqual(serverFeeFilter.feeRate, serverFeeRate)

        veracked = await serverNode.peers[peerInServer]!.receivedVersionAck
        XCTAssert(veracked)

        handshook = await serverNode.peers[peerInServer]!.handshakeComplete
        XCTAssert(handshook)

        // … --(sendcmpct)->> Server
        try await serverNode.processMessage(clientSendCompactMessage, from: peerInServer) // No response expected
        let serverCompatibleCompactBlocksVersion = await serverNode.peers[peerInServer]!.compatibleCompactBlocksVersion
        XCTAssert(serverCompatibleCompactBlocksVersion)

        // … --(ping)->> Server
        Task {
            try await serverNode.processMessage(clientPingMessage, from: peerInServer)
        }
        // … <<-(pong)-- Server
        guard let serverPongMessage = await serverMessages.next() else { XCTFail(); return }
        await Task.yield()
        XCTAssertEqual(serverPongMessage.command, .pong)
        let pong = try XCTUnwrap(PongMessage(serverPongMessage.payload))
        XCTAssertEqual(ping.nonce, pong.nonce)

        // … --(feefilter)->> Server
        try await serverNode.processMessage(clientFeeFilterMessage, from: peerInServer) // No response expected
        let serverFeeRateForClient = await serverNode.peers[peerInServer]!.feeFilterRate
        XCTAssertEqual(clientFeeRate, serverFeeRateForClient)

        // Client <<-(sendcmpct)-- …
        try await clientNode.processMessage(serverSendCompactMessage, from: peerInClient) // No response expected
        let clientCompatibleCompactBlocksVersion = await clientNode.peers[peerInClient]!.compatibleCompactBlocksVersion
        XCTAssert(clientCompatibleCompactBlocksVersion)

        // Client <<-(ping)-- …
        Task {
            try await clientNode.processMessage(serverPingMessage, from: peerInClient)
        }
        // Client --(pong)->> …
        guard let clientPongMessage = await clientMessages.next() else { XCTFail(); return }
        await Task.yield()
        XCTAssertEqual(clientPongMessage.command, .pong)

        // Client <<-(feefilter)-- …
        try await clientNode.processMessage(serverFeeFilterMessage, from: peerInClient) // No response expected
        let clientFeeRateForServer = await clientNode.peers[peerInClient]!.feeFilterRate
        XCTAssertEqual(serverFeeRate, clientFeeRateForServer)

        // Client <<-(pong)-- …
        try await clientNode.processMessage(serverPongMessage, from: peerInClient) // No response expected
        lastPingNonce = await clientNode.peers[peerInClient]!.lastPingNonce
        XCTAssertNil(lastPingNonce)

        // … --(pong)->> Server
        try await serverNode.processMessage(clientPongMessage, from: peerInServer) // No response expected
    }
}
