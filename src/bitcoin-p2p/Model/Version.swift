import Foundation
import NIOCore
import Bitcoin

public struct Version: Equatable {
    public init(versionIdentifier: VersionIdentifier, services: Services, receiverServices: Services, receiverAddress: IPv6Address, receiverPort: Int, transmitterServices: Services, transmitterAddress: IPv6Address, transmitterPort: Int, nonce: UInt64, userAgent: String, startHeight: Int, relay: Bool) {
        self.versionIdentifier = versionIdentifier
        self.services = services
        self.timestamp = Date(timeIntervalSince1970: Date.now.timeIntervalSince1970.rounded(.down))
        self.receiverServices = receiverServices
        self.receiverAddress = receiverAddress
        self.receiverPort = receiverPort
        self.transmitterServices = transmitterServices
        self.transmitterAddress = transmitterAddress
        self.transmitterPort = transmitterPort
        self.nonce = nonce
        self.userAgent = userAgent
        self.startHeight = startHeight
        self.relay = relay
    }
    
    public let versionIdentifier: VersionIdentifier
    public let services: Services
    public let timestamp: Date
    public let receiverServices: Services
    public let receiverAddress: IPv6Address
    public let receiverPort: Int
    public let transmitterServices: Services
    public let transmitterAddress: IPv6Address
    public let transmitterPort: Int
    public let nonce: UInt64
    public let userAgent: String
    public let startHeight: Int
    public let relay: Bool

    var userAgentData: Data {
        userAgent.data(using: .ascii)!
    }

    var size: Int {
        85 + userAgentData.varLenSize
    }

    public var data: Data {
        var ret = Data(count: size)
        var offset = ret.addBytes(versionIdentifier.rawValue)
        offset = ret.addBytes(services.rawValue, at: offset)
        offset = ret.addBytes(Int64(timestamp.timeIntervalSince1970), at: offset)
        offset = ret.addBytes(receiverServices.rawValue, at: offset)
        offset = ret.addData(receiverAddress.rawValue, at: offset)
        offset = ret.addBytes(UInt16(receiverPort).bigEndian, at: offset)
        offset = ret.addBytes(transmitterServices.rawValue, at: offset)
        offset = ret.addData(transmitterAddress.rawValue, at: offset)
        offset = ret.addBytes(UInt16(transmitterPort).bigEndian, at: offset)
        offset = ret.addBytes(nonce, at: offset)
        offset = ret.addData(userAgentData.varLenData, at: offset)
        offset = ret.addBytes(Int32(startHeight), at: offset)
        offset = ret.addBytes(relay, at: offset)
        return ret
    }

    public init?(_ data: Data) {
        guard data.count >= 85 else { return nil }

        var data = data
        guard let versionIdentifier = VersionIdentifier(data) else { return nil }
        self.versionIdentifier = versionIdentifier
        data = data.dropFirst(VersionIdentifier.size)

        guard let services = Services(data) else { return nil }
        self.services = services
        data = data.dropFirst(Services.size)

        guard data.count >= MemoryLayout<Int64>.size else { return nil }
        let timestamp = data.withUnsafeBytes {
            $0.loadUnaligned(as: Int64.self)
        }
        self.timestamp = Date(timeIntervalSince1970: TimeInterval(timestamp))
        data = data.dropFirst(MemoryLayout<Int64>.size)

        guard let receiverServices = Services(data) else { return nil }
        self.receiverServices = receiverServices
        data = data.dropFirst(Services.size)

        let receiverAddress = IPv6Address(data[..<data.startIndex.advanced(by: 16)])
        self.receiverAddress = receiverAddress
        data = data.dropFirst(16)

        guard data.count >= MemoryLayout<UInt16>.size else { return nil }
        let reveiverPort = data.withUnsafeBytes {
            $0.loadUnaligned(as: UInt16.self)
        }
        self.receiverPort = Int(reveiverPort.byteSwapped) // bigEndian -> littleEndian
        data = data.dropFirst(MemoryLayout<UInt16>.size)

        guard let transmitterServices = Services(data) else { return nil }
        self.transmitterServices = transmitterServices
        data = data.dropFirst(Services.size)

        let transmitterAddress = IPv6Address(data[..<data.startIndex.advanced(by: 16)])
        self.transmitterAddress = transmitterAddress
        data = data.dropFirst(16)

        guard data.count >= MemoryLayout<UInt16>.size else { return nil }
        let transmitterPort = data.withUnsafeBytes {
            $0.loadUnaligned(as: UInt16.self)
        }
        self.transmitterPort = Int(transmitterPort.byteSwapped)
        data = data.dropFirst(MemoryLayout<UInt16>.size)

        guard data.count >= MemoryLayout<UInt64>.size else { return nil }
        let nonce = data.withUnsafeBytes {
            $0.loadUnaligned(as: UInt64.self)
        }
        self.nonce = nonce
        data = data.dropFirst(MemoryLayout<UInt64>.size)

        guard let userAgentData = Data(varLenData: data) else {
            return nil
        }
        let userAgent = String(decoding: userAgentData, as: Unicode.ASCII.self)
        self.userAgent = userAgent
        data = data.dropFirst(userAgentData.varLenSize)

        guard data.count >= MemoryLayout<Int32>.size else { return nil }
        let startHeight = data.withUnsafeBytes {
            $0.loadUnaligned(as: Int32.self)
        }
        self.startHeight = Int(startHeight)
        data = data.dropFirst(MemoryLayout<Int32>.size)

        guard data.count >= MemoryLayout<Bool>.size else { return nil }
        let relay = data.withUnsafeBytes {
            $0.loadUnaligned(as: Bool.self)
        }
        self.relay = relay
        data = data.dropFirst(MemoryLayout<Bool>.size)
    }
}

public enum VersionIdentifier: Int32 {

    public init?(_ data: Data) {
        guard data.count >= MemoryLayout<RawValue>.size else { return nil }
        let rawValue = data.withUnsafeBytes {
            $0.loadUnaligned(as: RawValue.self)
        }
        self.init(rawValue: rawValue)
    }

    case latest = 70016

    static var size: Int { MemoryLayout<RawValue>.size }
}

public struct Services: OptionSet {
    public init(rawValue: UInt64) {
        self.rawValue = rawValue
    }
    
    public init?(_ data: Data) {
        guard data.count >= MemoryLayout<RawValue>.size else { return nil }
        let rawValue = data.withUnsafeBytes {
            $0.loadUnaligned(as: RawValue.self)
        }
        self.init(rawValue: rawValue)
    }

    public let rawValue: UInt64

    public static let network = Self(rawValue: 1 << 0)
    public static let witness = Self(rawValue: 1 << 3)

    public static let all: Services = [.network, .witness]

    static var size: Int { MemoryLayout<RawValue>.size }
}
