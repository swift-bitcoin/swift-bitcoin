import XCTest
@testable import Bitcoin
@testable import BitcoinP2P
import BitcoinCrypto

final class BitcoinPeerTests: XCTestCase {

    func testHandshake() async throws {
        let service1 = BitcoinService()
        let service2 = BitcoinService()

        let serverPeer = BitcoinPeer(bitcoinService: service1, isClient: false)
        let clientPeer = BitcoinPeer(bitcoinService: service2, isClient: true)

        let serverTask = Task {
            var count = 0
            for await message in await serverPeer.messagesOut {
                await clientPeer.messagesIn.send(message)
                if count == 1 { break }
                count += 1
            }
        }
        let clientTask = Task {
            var count = 0
            for await message in await clientPeer.messagesOut {
                await serverPeer.messagesIn.send(message)
                if count == 1 { break }
                count += 1
            }
        }

        Task {
            try await withThrowingDiscardingTaskGroup {
                $0.addTask {
                    try await serverPeer.start()
                }
                $0.addTask {
                    try await clientPeer.start()
                }
            }
        }

        await withDiscardingTaskGroup {
            $0.addTask {
                await serverTask.value
            }
            $0.addTask {
                await clientTask.value
            }
        }

        let serverHandshake = await serverPeer.handshakeComplete
        await Task.yield()
        let clientHandshake = await clientPeer.handshakeComplete
        XCTAssert(serverHandshake)
        XCTAssert(clientHandshake)
        try await clientPeer.stop()
        try await serverPeer.stop()
    }

    func testHandshakeSteps() async throws {
        let service1 = BitcoinService()
        let service2 = BitcoinService()

        let serverPeer = BitcoinPeer(bitcoinService: service1, isClient: false)
        let clientPeer = BitcoinPeer(bitcoinService: service2, isClient: true)

        var serverMessages = await serverPeer.messagesOut.makeAsyncIterator()
        var clientMessages = await clientPeer.messagesOut.makeAsyncIterator()

        Task {
            try await serverPeer.start()
        }
        Task {
            try await clientPeer.start()
        }

        guard let message = await clientMessages.next() else {
            XCTFail(); return
        }
        XCTAssertEqual(message.command, .version)
        await serverPeer.messagesIn.send(message)

        guard let message = await serverMessages.next() else {
            XCTFail(); return
        }
        XCTAssertEqual(message.command, .version)
        await clientPeer.messagesIn.send(message)

        guard let message = await clientMessages.next() else {
            XCTFail(); return
        }
        XCTAssertEqual(message.command, .verack)
        await serverPeer.messagesIn.send(message)

        var handshook = await serverPeer.handshakeComplete
        XCTAssertFalse(handshook)

        guard let message = await serverMessages.next() else {
            XCTFail(); return
        }
        XCTAssertEqual(message.command, .verack)

        handshook = await serverPeer.handshakeComplete
        XCTAssert(handshook)

        handshook = await clientPeer.handshakeComplete
        XCTAssertFalse(handshook)

        await clientPeer.messagesIn.send(message)
        await Task.yield()
        handshook = await clientPeer.handshakeComplete
        XCTAssert(handshook)

        try await clientPeer.stop()
        try await serverPeer.stop()
    }

    func testPingPong() async throws {
        let nodeA = BitcoinService()
        let nodeB = BitcoinService()

        let serverPeer = BitcoinPeer(bitcoinService: nodeA, isClient: false)
        let clientPeer = BitcoinPeer(bitcoinService: nodeB, isClient: true)

        let serverTask = Task {
            for await message in await serverPeer.messagesOut {
                if message.command == .pong {
                    return BitcoinMessage?.some(message)
                }
                await clientPeer.messagesIn.send(message)
            }
            return BitcoinMessage?.none
        }

        let clientTask = Task {
            for await message in await clientPeer.messagesOut {
                await serverPeer.messagesIn.send(message)
                if message.command == .ping {
                    return BitcoinMessage?.some(message)
                }
            }
            return BitcoinMessage?.none
        }

        Task {
            try await withThrowingDiscardingTaskGroup {
                $0.addTask {
                    try await serverPeer.start()
                }
                $0.addTask {
                    try await clientPeer.start()
                }
            }
        }

        // Initiate the ping
        try await clientPeer.sendPing()

        let (pingMessage, pongMessage) = try await withThrowingTaskGroup(of: BitcoinMessage?.self, returning: (BitcoinMessage, BitcoinMessage).self) { group in
            group.addTask {
                await serverTask.value
            }
            group.addTask {
                await clientTask.value
            }
            guard let firstResult = try await group.next(),
                  let secondResult = try await group.next(),
                  let firstMessage = firstResult,
                  let secondMessage = secondResult else {
                XCTFail()
                throw XCTSkip()
            }
            return if firstMessage.command == .ping { (firstMessage, secondMessage) } else { (secondMessage, firstMessage) }
        }

        try await clientPeer.stop()
        try await serverPeer.stop()

        let ping = try XCTUnwrap(PingMessage(pingMessage.payload))
        let pong = try XCTUnwrap(PongMessage(pongMessage.payload))
        XCTAssertEqual(ping.nonce, pong.nonce)
    }

    func testPingPongSteps() async throws {
        let service1 = BitcoinService()
        let service2 = BitcoinService()

        let serverPeer = BitcoinPeer(bitcoinService: service1, isClient: false)
        let clientPeer = BitcoinPeer(bitcoinService: service2, isClient: true)

        var serverMessages = await serverPeer.messagesOut.makeAsyncIterator()
        var clientMessages = await clientPeer.messagesOut.makeAsyncIterator()

        Task {
            try await serverPeer.start()
        }
        Task {
            try await clientPeer.start()
        }

        guard let message = await clientMessages.next() else { XCTFail(); return }
        await serverPeer.messagesIn.send(message)
        guard let message = await serverMessages.next() else { XCTFail(); return }
        await clientPeer.messagesIn.send(message)

        guard let message = await clientMessages.next() else { XCTFail(); return }
        await serverPeer.messagesIn.send(message)
        guard let message = await serverMessages.next() else { XCTFail(); return }
        await clientPeer.messagesIn.send(message)

        Task {
            try await clientPeer.sendPing()
        }
        guard let message = await clientMessages.next() else { XCTFail(); return }
        XCTAssertEqual(message.command, .ping)
        let ping = try XCTUnwrap(PingMessage(message.payload))
        await serverPeer.messagesIn.send(message)

        guard let message = await serverMessages.next() else { XCTFail(); return }
        XCTAssertEqual(message.command, .pong)
        let pong = try XCTUnwrap(PongMessage(message.payload))
        XCTAssertEqual(ping.nonce, pong.nonce)
        var lastPingNonce = await clientPeer.lastPingNonce
        XCTAssertEqual(pong.nonce, lastPingNonce) // FIXME: This failed once with lastPingNonce == nil

        await clientPeer.messagesIn.send(message)
        await Task.yield()
        lastPingNonce = await clientPeer.lastPingNonce
        XCTAssertNil(lastPingNonce)  // FIXME: This failed a different time with lastPingNonce != nil

        try await clientPeer.stop()
        try await serverPeer.stop()
    }
}
