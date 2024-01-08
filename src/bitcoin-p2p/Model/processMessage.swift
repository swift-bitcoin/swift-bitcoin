import Foundation

public func getFirstMessage(context: inout PeerContext) -> Message {
    print("Server contacted.")
    print("Sending VERSION message to server…")
    print("Handshake initiated.")
    debugPrint(context.localVersion)
    let versionData = context.localVersion.data
    return Message(network: .regtest, command: "version", payload: versionData)
}

public func processMessage(_ message: Message, context: inout PeerContext) throws -> Message? {
    if context.isClient {
        if message.command == "version" {

            print("Received VERSION message from server.")
            guard let theirVersion = Version(message.payload) else {
                print("Cannot decode server's version.")
                preconditionFailure()
            }
            debugPrint(theirVersion)
            if context.localVersion.versionIdentifier == theirVersion.versionIdentifier {
                print("Protocol version identifiers match.")
            }
            print("Sending VERACK message to server…")
            return Message(network: .regtest, command: "verack", payload: Data())
        } else if message.command == "verack" {
            context.handshakeComplete = true
            print("Received VERACK message from server.")
            print("Handshake successful.")
        }
        return .none
    }
    // Server
    if message.command == "version" {
        print("Received VERSION message from client.")
        let receiverAddress = IPv6Address(IPv4Address.loopback)
        let version = Version(versionIdentifier: .latest, services: .all, receiverServices: .all, receiverAddress: receiverAddress, receiverPort: 18444, transmitterServices: .all, transmitterAddress: .init(Data(repeating: 0x00, count: 16)), transmitterPort: 0, nonce: 0xF85379C9CB358012, userAgent: "/Satoshi:25.1.0/", startHeight: 329167, relay: true)
        let versionData = version.data
        print("Sending VERSION mesage to client…")
        return Message(network: .regtest, command: "version", payload: versionData)

    } else if message.command == "verack" {
        print("Received VERACK message from client.")
        print("Handshake successful.")
        print("Sending VERACK message to client…")
        return Message(network: .regtest, command: "verack", payload: Data())

    }
    preconditionFailure()
}
