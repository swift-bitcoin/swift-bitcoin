import Foundation

public enum NodeNetwork: String, Sendable {
    case main, test, signet, regtest

    /// Also known as block and message header.
    public var magicBytes: UInt32 {
        switch self {
        case .main: 0xd9b4bef9
        case .test: 0x0709110b
        case .signet: 0x40cf030a // TODO: Signet Genesis Block and Message Header All signet networks share the same genesis block, but have a different message header. The message header is the 4 first bytes of the sha256d-hash of the block challenge, as a single script push operation. I.e. if the block challenge is 37 bytes, the message start would be sha256d(0x25 || challenge)[0..3]. https://en.bitcoin.it/wiki/Signet#Genesis_Block_and_Message_Header
        case .regtest: 0xdab5bffa
        }
    }

    public var defaultRPCPort: Int {
        switch self {
        case .main: 8332
        case .test: 18332
        case .signet: 38332
        case .regtest: 18443
        }
    }

    public var defaultP2PPort: Int {
        switch self {
        case .main: 8333
        case .test: 18333
        case .signet: 38333
        case .regtest: 18444
        }
    }
}

public extension NodeNetwork {

    init?(_ data: Data) {
        guard data.count >= MemoryLayout<UInt32>.size else { return nil }
        let magicBytes = data.withUnsafeBytes {
            $0.loadUnaligned(as: UInt32.self)
        }
        switch magicBytes {
        case Self.main.magicBytes:
            self = .main
        case Self.test.magicBytes:
            self = .test
        case Self.signet.magicBytes:
            self = .signet
        case Self.regtest.magicBytes:
            self = .regtest
        default:
            return nil
        }
    }

    var data: Data {
        Data(value: magicBytes)
    }

    static var size: Int { MemoryLayout<UInt32>.size }
}
