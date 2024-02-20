import Foundation
import Bitcoin
import AsyncAlgorithms

public actor BitcoinPeer {

    public init(bitcoinService: BitcoinService, isClient: Bool) {
        self.bitcoinService = bitcoinService
        self.isClient = isClient
    }

    private let bitcoinService: BitcoinService
    private let isClient: Bool
    public let messagesIn = AsyncChannel<Message>()
    public let messagesOut = AsyncChannel<Message>()

    private var blocks = AsyncChannel<TransactionBlock>?.none

    private var localVersion: Version = {
        let receiverAddress = IPv6Address(IPv4Address.loopback)
        return Version(versionIdentifier: .latest, services: .all, receiverServices: .all, receiverAddress: receiverAddress, receiverPort: 18444, transmitterServices: .all, transmitterAddress: .init(Data(repeating: 0x00, count: 16)), transmitterPort: 0, nonce: 0xF85379C9CB358012, userAgent: "/Satoshi:25.1.0/", startHeight: 916, relay: true)
    }()
    private var version = VersionIdentifier?.none
    private(set) var handshakeComplete = false
    private(set) var lastPingNonce = UInt64?.none

    public func start() async throws {

        if isClient {
            let message = getFirstMessage()
            debugPrint(message)
            await messagesOut.send(message)
        }

        let blocks = await bitcoinService.blocks
        Task {
            for await block in blocks {
                print("New block (might send to peer):\n\t\(block.hash.hex)]")
            }
        }

        for try await message in messagesIn {
            if let response = try processMessage(message) {
                await messagesOut.send(response)
            }
        }
    }

    public func stop() async throws {
        messagesIn.finish()
        messagesOut.finish()
        if let blocks {
            await bitcoinService.unsubscribe(blocks)
        }
    }

    public func sendPing() async throws {
        let ping = makePingMessage()
        debugPrint(ping)
        await messagesOut.send(ping)
    }

    private func getFirstMessage() -> Message {
        print("Handshake initiated.")
        debugPrint(localVersion)
        let versionData = localVersion.data
        return Message(network: .regtest, command: .version, payload: versionData)
    }

    private func makePingMessage() -> Message {
        let ping = Ping()
        lastPingNonce = ping.nonce
        return Message(network: .regtest, command: .ping, payload: ping.data)
    }

    private func processMessage(_ message: Message) throws -> Message? {
        print("\n<<<")
        debugPrint(message)
        let response = switch message.command {
        case .version:
            try processVersion(message)
        case .verack:
            try processVerack(message)
        case .ping:
            try processPing(message)
        case .pong:
            try processPong(message)
        }
        if let response {
            debugPrint(response)
        } else {
            print("No response sent.")
        }
        print(">>>\n")
        return response
    }

    private func processVersion(_ message: Message) throws -> Message? {
        if isClient {
            guard let theirVersion = Version(message.payload) else {
                print("Cannot decode server's version.")
                preconditionFailure()
            }
            debugPrint(theirVersion)
            if localVersion.versionIdentifier == theirVersion.versionIdentifier {
                print("Protocol version identifiers match.")
            }
            return Message(network: .regtest, command: .verack, payload: Data())
        }
        // Server
        let receiverAddress = IPv6Address(IPv4Address.loopback)
        let version = Version(versionIdentifier: .latest, services: .all, receiverServices: .all, receiverAddress: receiverAddress, receiverPort: 18444, transmitterServices: .all, transmitterAddress: .init(Data(repeating: 0x00, count: 16)), transmitterPort: 0, nonce: 0xF85379C9CB358012, userAgent: "/Satoshi:25.1.0/", startHeight: 329167, relay: true)
        let versionData = version.data
        return Message(network: .regtest, command: .version, payload: versionData)
    }

    private func processVerack(_ message: Message) throws -> Message? {
        if isClient {
            handshakeComplete = true
            print("Handshake successful.")
            return .none
        }
        // Server
        handshakeComplete = true
        print("Handshake successful.")
        return Message(network: .regtest, command: .verack, payload: .init())
    }

    private func processPing(_ message: Message) throws -> Message? {
        guard let ping = Ping(message.payload) else {
            // TODO: Send reject and disconnect.
            preconditionFailure()
        }
        debugPrint(ping)
        let pong = Pong(nonce: ping.nonce)
        debugPrint(pong)
        return Message(network: .regtest, command: .pong, payload: pong.data)
    }

    private func processPong(_ message: Message) throws -> Message? {
        guard let pong = Pong(message.payload) else {
            // TODO: Send reject (#165) and disconnect.
            print("Wrong pong")
            preconditionFailure()
        }
        debugPrint(pong)
        guard let nonce = lastPingNonce, pong.nonce == nonce else {
            // TODO: Send reject (#165) and disconnect.
            print("Wrong nonce")
            preconditionFailure()
        }
        lastPingNonce = .none
        return .none
    }
}
