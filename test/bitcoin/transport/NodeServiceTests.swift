import XCTest
import Bitcoin

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

        guard let message = await clientMessages.next() else {
            XCTFail(); return
        }
        XCTAssertEqual(message.command, .version)
        do { try await serverNode.processMessage(message, from: peerInServer) } catch { XCTFail(); return }

        guard let message = await serverMessages.next() else {
            XCTFail(); return
        }
        XCTAssertEqual(message.command, .version)
        do { try await clientNode.processMessage(message, from: peerInClient) } catch { XCTFail(); return }

        guard let message = await serverMessages.next() else {
            XCTFail(); return
        }
        XCTAssertEqual(message.command, .sendaddrv2)
        do { try await clientNode.processMessage(message, from: peerInClient) } catch { XCTFail(); return }

        guard let message = await clientMessages.next() else {
            XCTFail(); return
        }
        XCTAssertEqual(message.command, .sendaddrv2)
        do { try await serverNode.processMessage(message, from: peerInServer) } catch { XCTFail(); return }

        guard let message = await clientMessages.next() else {
            XCTFail(); return
        }
        XCTAssertEqual(message.command, .verack)

        var handshook = await serverNode.peers[peerInServer]!.handshakeComplete
        XCTAssertFalse(handshook)

        do { try await serverNode.processMessage(message, from: peerInServer) } catch { XCTFail(); return }

        handshook = await serverNode.peers[peerInServer]!.handshakeComplete
        XCTAssert(handshook)

        guard let message = await serverMessages.next() else {
            XCTFail(); return
        }
        XCTAssertEqual(message.command, .verack)

        handshook = await clientNode.peers[peerInClient]!.handshakeComplete
        XCTAssertFalse(handshook)

        do { try await clientNode.processMessage(message, from: peerInClient) } catch { XCTFail(); return }

        handshook = await clientNode.peers[peerInClient]!.handshakeComplete
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

        guard let message = await clientMessages.next() else { XCTFail(); return }
        do { try await serverNode.processMessage(message, from: peerInServer) } catch { XCTFail(); return }
        guard let message = await serverMessages.next() else { XCTFail(); return }
        do { try await clientNode.processMessage(message, from: peerInClient) } catch { XCTFail(); return }
        guard let message = await serverMessages.next() else { XCTFail(); return }
        do { try await clientNode.processMessage(message, from: peerInClient) } catch { XCTFail(); return }
        guard let message = await clientMessages.next() else { XCTFail(); return }
        do { try await serverNode.processMessage(message, from: peerInServer) } catch { XCTFail(); return }
        guard let message = await clientMessages.next() else { XCTFail(); return }
        do { try await serverNode.processMessage(message, from: peerInServer) } catch { XCTFail(); return }
        guard let message = await serverMessages.next() else { XCTFail(); return }
        do { try await clientNode.processMessage(message, from: peerInClient) } catch { XCTFail(); return }

        Task {
            await clientNode.pingAll() // Only one peer to ping
        }
        guard let message = await clientMessages.next() else { XCTFail(); return }
        XCTAssertEqual(message.command, .ping)
        let ping = try XCTUnwrap(PingMessage(message.payload))
        do { try await serverNode.processMessage(message, from: peerInServer) } catch { XCTFail(); return }

        guard let message = await serverMessages.next() else { XCTFail(); return }
        XCTAssertEqual(message.command, .pong)
        let pong = try XCTUnwrap(PongMessage(message.payload))
        XCTAssertEqual(ping.nonce, pong.nonce)
        var lastPingNonce = await clientNode.peers[peerInClient]!.lastPingNonce
        XCTAssertEqual(pong.nonce, lastPingNonce) // FIXME: This failed once with lastPingNonce == nil

        do { try await clientNode.processMessage(message, from: peerInClient) } catch { XCTFail(); return }

        lastPingNonce = await clientNode.peers[peerInClient]!.lastPingNonce
        XCTAssertNil(lastPingNonce)  // FIXME: This failed a different time with lastPingNonce != nil
    }
}
