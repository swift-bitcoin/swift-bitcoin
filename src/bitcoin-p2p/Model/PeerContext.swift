import Foundation
import Network

public struct PeerContext {
    public init(isClient: Bool = true) {
        self.isClient = isClient
    }

    public var isClient: Bool
    public var localVersion: Version = {
        let receiverAddress = IPv6Address(Data(repeating: 0x00, count: 10) + Data(repeating: 0xff, count: 2) + IPv4Address.loopback.rawValue)!
        return Version(versionIdentifier: .latest, services: .all, receiverServices: .all, receiverAddress: receiverAddress, receiverPort: 18444, transmitterServices: .all, transmitterAddress: .init(Data(repeating: 0x00, count: 16))!, transmitterPort: 0, nonce: 0xF85379C9CB358012, userAgent: "/Satoshi:25.1.0/", startHeight: 916, relay: true)
    }()
    public var version = VersionIdentifier?.none
    public var handshakeComplete = false
}
