import XCTest
@testable import Bitcoin

final class NodeServiceTests: XCTestCase {

     func testHandshake() async throws {
        let serviceA = BitcoinService()
        let serviceB = BitcoinService()
        let serverNode = NodeService(bitcoinService: serviceA)
        let clientNode = NodeService(bitcoinService: serviceB)
        let peerInServer = await serverNode.addPeer(host: "", port: 0)
        let peerInClient = await clientNode.addPeer(host: "", port: 0, incoming: false)
        var serverMessages = await serverNode.getChannel(for: peerInServer).makeAsyncIterator()
        var clientMessages = await clientNode.getChannel(for: peerInClient).makeAsyncIterator()

        Task {
            await clientNode.connect(peerInClient)
        }
        guard let message0 = await clientMessages.next() else { XCTFail(); return }
        await Task.yield()
        XCTAssertEqual(message0.command, .version)

        Task {
            try await serverNode.processMessage(message0, from: peerInServer)
        }
        guard let message1 = await serverMessages.next() else { XCTFail(); return }
        await Task.yield()
        XCTAssertEqual(message1.command, .version)
        guard let message2 = await serverMessages.next() else { XCTFail(); return }
        await Task.yield()
        XCTAssertEqual(message2.command, .sendaddrv2)
        guard let message3 = await serverMessages.next() else { XCTFail(); return }
        await Task.yield()
        XCTAssertEqual(message3.command, .verack)

        Task {
            try await clientNode.processMessage(message1, from: peerInClient)
        }
        guard let message4 = await clientMessages.next() else { XCTFail(); return }
        await Task.yield()
        XCTAssertEqual(message4.command, .sendaddrv2)
        guard let message5 = await clientMessages.next() else { XCTFail(); return }
        await Task.yield()
        XCTAssertEqual(message5.command, .verack)

        var versionReceived = await clientNode.peers[peerInClient]!.receivedVersion
        XCTAssert(versionReceived)

        try await clientNode.processMessage(message2, from: peerInClient)
        var v2Addr = await clientNode.peers[peerInClient]!.receivedV2AddressPreference
        XCTAssert(v2Addr)

        try await clientNode.processMessage(message3, from: peerInClient)
        var veracked = await clientNode.peers[peerInClient]!.receivedVersionAck
        XCTAssert(veracked)
        var handshook = await clientNode.peers[peerInClient]!.handshakeComplete
        XCTAssert(handshook)

        try await serverNode.processMessage(message4, from: peerInServer)
        v2Addr = await serverNode.peers[peerInServer]!.receivedV2AddressPreference
        XCTAssert(v2Addr)

        try await serverNode.processMessage(message5, from: peerInServer)
        veracked = await serverNode.peers[peerInServer]!.receivedVersionAck
        XCTAssert(veracked)

        handshook = await serverNode.peers[peerInServer]!.handshakeComplete
        XCTAssert(handshook)
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
        guard let message0 = await clientMessages.next() else { XCTFail(); return }
        await Task.yield()

        Task {
            try await serverNode.processMessage(message0, from: peerInServer)
        }
        guard let message1 = await serverMessages.next() else { XCTFail(); return }
        await Task.yield()
        guard let message2 = await serverMessages.next() else { XCTFail(); return }
        await Task.yield()
        guard let message3 = await serverMessages.next() else { XCTFail(); return }
        await Task.yield()

        Task {
            try await clientNode.processMessage(message1, from: peerInClient)
        }
        guard let message4 = await clientMessages.next() else { XCTFail(); return }
        await Task.yield()
        guard let message5 = await clientMessages.next() else { XCTFail(); return }
        await Task.yield()

        try await clientNode.processMessage(message2, from: peerInClient)
        try await clientNode.processMessage(message3, from: peerInClient)
        try await serverNode.processMessage(message4, from: peerInServer)
        try await serverNode.processMessage(message5, from: peerInServer)

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
