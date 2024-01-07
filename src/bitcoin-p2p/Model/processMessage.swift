import Foundation
import Network

public func getFirstMessage(context: inout PeerContext) -> Message {
    print("Initial connection to server established.")
    print("Sending our version to server. Handshake initiated.")
    debugPrint(context.localVersion)
    let versionData = context.localVersion.data
    return Message(network: .regtest, command: "version", payload: versionData)
}

public func processMessage(_ message: Message, context: inout PeerContext) throws -> Message? {
    if context.isClient {
        if message.command == "version" {

            print("Version received from server.")
            guard let theirVersion = Version(message.payload) else {
                print("Can't decode their version.")
                preconditionFailure()
            }
            debugPrint(theirVersion)
            if context.localVersion.versionIdentifier == theirVersion.versionIdentifier {
                print("Protocol version identifiers match.")
            }
            print("Sending verack to server.")
            return Message(network: .regtest, command: "verack", payload: Data())
        } else if message.command == "verack" {
            context.handshakeComplete = true
            print("Verack received from server. Handshake successful.")
        }
        return .none
    }
    // Server
    if message.command == "version" {
        print("Received version command message from client.")
        let receiverAddress = IPv6Address(Data(repeating: 0x00, count: 10) + Data(repeating: 0xff, count: 2) + IPv4Address.loopback.rawValue)!
        let version = Version(versionIdentifier: .latest, services: .all, receiverServices: .all, receiverAddress: receiverAddress, receiverPort: 18444, transmitterServices: .all, transmitterAddress: .init(Data(repeating: 0x00, count: 16))!, transmitterPort: 0, nonce: 0xF85379C9CB358012, userAgent: "/Satoshi:25.1.0/", startHeight: 329167, relay: true)
        let versionData = version.data
        print("Sending version message back to client.")
        return Message(network: .regtest, command: "version", payload: versionData)

    } else if message.command == "verack" {
        print("Received verack message from client.")
        print("Sending verack message back to client.")
        return Message(network: .regtest, command: "verack", payload: Data())

    }
    preconditionFailure()
}
