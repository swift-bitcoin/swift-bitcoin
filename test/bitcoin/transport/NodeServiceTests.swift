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
    func testHandshake() async throws {
        let serviceA = BitcoinService()
        let serviceB = BitcoinService()
        let serverNode = NodeService(bitcoinService: serviceA, feeFilterRate: 2)
        let clientNode = NodeService(bitcoinService: serviceB, feeFilterRate: 3)
        let peerInServer = await serverNode.addPeer(host: "", port: 0)
        let peerInClient = await clientNode.addPeer(host: "", port: 0, incoming: false)
        var serverMessages = await serverNode.getChannel(for: peerInServer).makeAsyncIterator()
        var clientMessages = await clientNode.getChannel(for: peerInClient).makeAsyncIterator()

        Task {
            await clientNode.connect(peerInClient)
        }
        guard let clientVersion = await clientMessages.next() else { XCTFail(); return }
        await Task.yield()
        XCTAssertEqual(clientVersion.command, .version)

        Task {
            try await serverNode.processMessage(clientVersion, from: peerInServer)
        }
        guard let serverVersion = await serverMessages.next() else { XCTFail(); return }
        await Task.yield()
        XCTAssertEqual(serverVersion.command, .version)
        guard let serverSendAddrV2 = await serverMessages.next() else { XCTFail(); return }
        await Task.yield()
        XCTAssertEqual(serverSendAddrV2.command, .sendaddrv2)
        guard let serverVerack = await serverMessages.next() else { XCTFail(); return }
        await Task.yield()
        XCTAssertEqual(serverVerack.command, .verack)

        Task {
            try await clientNode.processMessage(serverVersion, from: peerInClient)
        }
        guard let clientSendAddrV2 = await clientMessages.next() else { XCTFail(); return }
        await Task.yield()
        XCTAssertEqual(clientSendAddrV2.command, .sendaddrv2)
        guard let clientVerack = await clientMessages.next() else { XCTFail(); return }
        await Task.yield()
        XCTAssertEqual(clientVerack.command, .verack)

        let versionReceived = await clientNode.peers[peerInClient]!.receivedVersion
        XCTAssert(versionReceived)

        try await clientNode.processMessage(serverSendAddrV2, from: peerInClient)
        var v2Addr = await clientNode.peers[peerInClient]!.receivedV2AddressPreference
        XCTAssert(v2Addr)

        Task {
            try await clientNode.processMessage(serverVerack, from: peerInClient)
        }
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

        try await serverNode.processMessage(clientSendAddrV2, from: peerInServer)
        v2Addr = await serverNode.peers[peerInServer]!.receivedV2AddressPreference
        XCTAssert(v2Addr)

        Task {
            try await serverNode.processMessage(clientVerack, from: peerInServer)
        }
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

        try await serverNode.processMessage(clientFeeFilterMessage, from: peerInServer) // No response expected
        let serverFeeRateForClient = await serverNode.peers[peerInServer]!.feeFilterRate
        XCTAssertEqual(clientFeeRate, serverFeeRateForClient)

        try await clientNode.processMessage(serverFeeFilterMessage, from: peerInClient) // No response expected
        let clientFeeRateForServer = await clientNode.peers[peerInClient]!.feeFilterRate
        XCTAssertEqual(serverFeeRate, clientFeeRateForServer)
    }

    func testPingPong() async throws {
        let serviceA = BitcoinService()
        let serviceB = BitcoinService()
        let serverNode = NodeService(bitcoinService: serviceA)
        let clientNode = NodeService(bitcoinService: serviceB)
        let peerInServer = await serverNode.addPeer(host: "", port: 0)
        let peerInClient = await clientNode.addPeer(host: "", port: 0, incoming: false)
        var serverMessages = await serverNode.getChannel(for: peerInServer).makeAsyncIterator()
        var clientMessages = await clientNode.getChannel(for: peerInClient).makeAsyncIterator()

        Task { await clientNode.connect(peerInClient) }
        guard let clientVersion = await clientMessages.next() else { XCTFail(); return }
        await Task.yield()

        Task {
            try await serverNode.processMessage(clientVersion, from: peerInServer)
        }
        guard let serverVersion = await serverMessages.next() else { XCTFail(); return }
        await Task.yield()
        guard let serverSendAddrV2 = await serverMessages.next() else { XCTFail(); return }
        await Task.yield()
        guard let serverVerack = await serverMessages.next() else { XCTFail(); return }
        await Task.yield()

        Task {
            try await clientNode.processMessage(serverVersion, from: peerInClient)
        }
        guard let clientSendAddrV2 = await clientMessages.next() else { XCTFail(); return }
        await Task.yield()
        guard let clientVerack = await clientMessages.next() else { XCTFail(); return }
        await Task.yield()

        try await clientNode.processMessage(serverSendAddrV2, from: peerInClient)
        Task {
            try await clientNode.processMessage(serverVerack, from: peerInClient)
        }
        guard let clientFeeFilter = await clientMessages.next() else { XCTFail(); return }
        await Task.yield()

        try await serverNode.processMessage(clientSendAddrV2, from: peerInServer)
        Task {
            try await serverNode.processMessage(clientVerack, from: peerInServer)
        }
        guard let serverFeeFilter = await serverMessages.next() else { XCTFail(); return }
        await Task.yield()

        try await serverNode.processMessage(clientFeeFilter, from: peerInServer)
        try await clientNode.processMessage(serverFeeFilter, from: peerInClient)

        Task {
            await clientNode.pingAll()
        }
        guard let message6 = await clientMessages.next() else { XCTFail(); return }
        await Task.yield()
        XCTAssertEqual(message6.command, .ping)
        let ping = try XCTUnwrap(PingMessage(message6.payload))

        var lastPingNonce = await clientNode.peers[peerInClient]!.lastPingNonce
        XCTAssertNotNil(lastPingNonce)

        Task {
            try await serverNode.processMessage(message6, from: peerInServer)
        }
        guard let message7 = await serverMessages.next() else { XCTFail(); return }
        await Task.yield()
        XCTAssertEqual(message7.command, .pong)
        let pong = try XCTUnwrap(PongMessage(message7.payload))
        XCTAssertEqual(ping.nonce, pong.nonce)

        try await clientNode.processMessage(message7, from: peerInClient)
        lastPingNonce = await clientNode.peers[peerInClient]!.lastPingNonce
        XCTAssertNil(lastPingNonce)
    }
}
