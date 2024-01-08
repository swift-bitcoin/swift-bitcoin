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
        var data = Data(capacity: size)
        data.addBytes(of: versionIdentifier.rawValue)
        data.addBytes(of: services.rawValue)
        data.addBytes(of: Int64(timestamp.timeIntervalSince1970))
        data.addBytes(of: receiverServices.rawValue)
        data.append(receiverAddress.rawValue)
        data.addBytes(of: UInt16(receiverPort).bigEndian)
        data.addBytes(of: transmitterServices.rawValue)
        data.append(transmitterAddress.rawValue)
        data.addBytes(of: UInt16(transmitterPort).bigEndian)
        data.addBytes(of: nonce)
        data.append(userAgentData.varLenData)
        data.addBytes(of: Int32(startHeight))
        data.addBytes(of: relay)
        return data
    }

    public init?(_ data: Data) {
        guard data.count >= 85 else { return nil }

        var remainingData = data
        guard let versionIdentifier = VersionIdentifier(remainingData) else { return nil }
        self.versionIdentifier = versionIdentifier
        remainingData = remainingData.dropFirst(VersionIdentifier.size)

        guard let services = Services(remainingData) else { return nil }
        self.services = services
        remainingData = remainingData.dropFirst(Services.size)

        guard remainingData.count >= MemoryLayout<Int64>.size else { return nil }
        let timestamp = remainingData.withUnsafeBytes {
            $0.loadUnaligned(as: Int64.self)
        }
        self.timestamp = Date(timeIntervalSince1970: TimeInterval(timestamp))
        remainingData = remainingData.dropFirst(MemoryLayout<Int64>.size)

        guard let receiverServices = Services(remainingData) else { return nil }
        self.receiverServices = receiverServices
        remainingData = remainingData.dropFirst(Services.size)

        let receiverAddress = IPv6Address(remainingData[..<remainingData.startIndex.advanced(by: 16)])
        self.receiverAddress = receiverAddress
        remainingData = remainingData.dropFirst(16)

        guard remainingData.count >= MemoryLayout<UInt16>.size else { return nil }
        let reveiverPort = remainingData.withUnsafeBytes {
            $0.loadUnaligned(as: UInt16.self)
        }
        self.receiverPort = Int(reveiverPort.byteSwapped) // bigEndian -> littleEndian
        remainingData = remainingData.dropFirst(MemoryLayout<UInt16>.size)

        guard let transmitterServices = Services(remainingData) else { return nil }
        self.transmitterServices = transmitterServices
        remainingData = remainingData.dropFirst(Services.size)

        let transmitterAddress = IPv6Address(remainingData[..<remainingData.startIndex.advanced(by: 16)])
        self.transmitterAddress = transmitterAddress
        remainingData = remainingData.dropFirst(16)

        guard remainingData.count >= MemoryLayout<UInt16>.size else { return nil }
        let transmitterPort = remainingData.withUnsafeBytes {
            $0.loadUnaligned(as: UInt16.self)
        }
        self.transmitterPort = Int(transmitterPort.byteSwapped)
        remainingData = remainingData.dropFirst(MemoryLayout<UInt16>.size)

        guard remainingData.count >= MemoryLayout<UInt64>.size else { return nil }
        let nonce = remainingData.withUnsafeBytes {
            $0.loadUnaligned(as: UInt64.self)
        }
        self.nonce = nonce
        remainingData = remainingData.dropFirst(MemoryLayout<UInt64>.size)

        guard let userAgentData = Data(varLenData: remainingData) else {
            return nil
        }
        let userAgent = String(decoding: userAgentData, as: Unicode.ASCII.self)
        self.userAgent = userAgent
        remainingData = remainingData.dropFirst(userAgentData.varLenSize)

        guard remainingData.count >= MemoryLayout<Int32>.size else { return nil }
        let startHeight = remainingData.withUnsafeBytes {
            $0.loadUnaligned(as: Int32.self)
        }
        self.startHeight = Int(startHeight)
        remainingData = remainingData.dropFirst(MemoryLayout<Int32>.size)

        guard remainingData.count >= MemoryLayout<Bool>.size else { return nil }
        let relay = remainingData.withUnsafeBytes {
            $0.loadUnaligned(as: Bool.self)
        }
        self.relay = relay
        remainingData = remainingData.dropFirst(MemoryLayout<Bool>.size)
    }
}

extension Data {
    mutating func addBytes<T>(of value: T) {
        self.append(Swift.withUnsafeBytes(of: value) { Data($0) })
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
