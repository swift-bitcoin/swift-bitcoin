import XCTest
@testable import Bitcoin
@testable import BitcoinP2P
import BitcoinCrypto

final class BitcoinPeerTests: XCTestCase {

    func testHandshake() async throws {
        let service1 = BitcoinService()
        let service2 = BitcoinService()

        let peer1 = BitcoinPeer(bitcoinService: service1, isClient: false)
        let peer2 = BitcoinPeer(bitcoinService: service2, isClient: true)

        let serverTask = Task {
            var count = 0
            for await message in await peer1.messagesOut {
                await peer2.messagesIn.send(message)
                if count == 1 { break }
                count += 1
            }
        }
        let clientTask = Task {
            var count = 0
            for await message in await peer2.messagesOut {
                await peer1.messagesIn.send(message)
                if count == 1 { break }
                count += 1
            }
        }
        Task {
            try await peer1.start()
        }
        Task {
            try await peer2.start()
        }

        await withDiscardingTaskGroup {
            $0.addTask {
                await serverTask.value
            }
            $0.addTask {
                await clientTask.value
            }
        }

        let peer1Handshake = await peer1.handshakeComplete
        let peer2Handshake = await peer2.handshakeComplete
        XCTAssert(peer1Handshake)
        XCTAssert(peer2Handshake)
        try await peer2.stop()
        try await peer1.stop()
    }
}
