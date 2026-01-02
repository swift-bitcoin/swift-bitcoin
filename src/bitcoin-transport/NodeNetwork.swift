import Foundation

public enum NodeNetwork: String, Sendable, CaseIterable, CustomStringConvertible, Identifiable {
    case mainnet, testnet /*, signet */, regtest

    /// Also known as block and message header.
    public var magicBytes: UInt32 {
        switch self {
        case .mainnet: 0xd9b4bef9
        //case .testnet3: 0709110b
        case .testnet: 0x283f161c
        case .regtest: 0xdab5bffa
        // case .signet: 0x40cf030a
        // TODO: Signet Genesis Block and Message Header All signet networks share the same genesis block, but have a different message header. The message header is the 4 first bytes of the sha256d-hash of the block challenge, as a single script push operation. I.e. if the block challenge is 37 bytes, the message start would be sha256d(0x25 || challenge)[0..3]. https://en.bitcoin.it/wiki/Signet#Genesis_Block_and_Message_Header
        }
    }

    public var defaultRPCPort: Int {
        switch self {
        case .mainnet: 8332
        //case .testnet3: 18332
        case .testnet: 48332
        case .regtest: 18443
        // case .signet: 38332
        }
    }

    public var defaultP2PPort: Int {
        switch self {
        case .mainnet: 8333
        //case .testnet3: 18333
        case .testnet: 48333
        case .regtest: 18444
        // case .signet: 38333
        }
    }

    public var id: String {
        rawValue
    }

    public var description: String {
        rawValue.capitalized
    }

    public var autoconnectPeers: [(host: String, port: Int)] {
        switch self {
        case .testnet: [
            // Taken from https://github.com/bitcoin/bitcoin/blob/e221b2524659d22cc5a2b0d0023254115a7a5622/contrib/seeds/nodes_testnet4.txt
            ("2.59.134.244", 48333),
            ("5.182.4.106", 48333),
            ("18.189.156.102", 48333),
            ("31.57.46.104", 48333),
            ("35.201.167.154", 48333),
            ("38.102.86.40", 48333),
            ("38.111.111.224", 48333),
            ("38.121.43.211", 48333),
            ("45.41.204.15", 48333),
            ("45.41.204.28", 48333),
            ("45.94.168.5", 48333),
            ("50.19.171.211", 48333),
            ("51.158.61.33", 48333),
            ("62.164.218.78", 48333),
            ("69.26.129.172", 48333),
            ("74.48.195.218", 48333),
            ("74.133.9.162", 48333),
            ("80.253.94.252", 48333),
            ("82.67.102.15", 48333),
            ("89.166.29.73", 48333),
            ("94.183.188.204", 48333),
            ("95.141.35.117", 48333),
            ("103.99.168.207", 48333),
            ("103.99.171.212", 48333),
            ("103.165.192.207", 48333),
            ("103.165.192.208", 48333),
            ("103.232.248.31", 48333),
            ("104.194.153.147", 48333),
            ("104.237.131.138", 48333),
            ("107.189.25.136", 48333),
            ("108.171.193.104", 48333),
            ("109.123.236.96", 48333),
            ("134.195.88.56", 48333),
            ("135.180.99.74", 48333),
            ("144.76.2.169", 48333),
            ("158.220.90.103", 48333),
            ("165.227.226.132", 48333),
            ("168.119.11.220", 48333),
            ("172.86.95.71", 48333),
            ("172.93.167.68", 48333),
            ("172.93.167.89", 48333),
            ("181.174.164.74", 48333),
            ("185.232.70.226", 48333),
            ("185.254.97.76", 48333),
            ("203.132.94.196", 48333),
            ("208.68.4.71", 48333),
            ("217.31.57.128", 48333),
            ("222.66.94.2", 48333),
        ]
        case .mainnet: [
            ("5.59.96.54", 8333),
            ("5.128.87.126", 8333),
            ("5.186.40.82", 8333),
            ("5.186.63.8", 8333),
            ("8.9.160.156", 8333),
            ("8.211.63.145", 8333),
            ("12.1.162.60", 8333),
            ("14.161.253.253", 8333),
            ("23.16.135.74", 8333),
            ("23.175.0.202", 8333),
            ("23.175.0.220", 8333),
            ("23.245.136.142", 8333),
            ("23.245.201.64", 8333),
            ("24.0.172.43", 8333),
            ("24.35.81.15", 8333),
            ("24.36.120.129", 8333),
            ("24.49.240.218", 8333),
            ("24.78.60.65", 8333),
            ("24.96.59.158", 8333),
            ("24.109.211.59", 8333),
            ("24.116.126.187", 8333),
        ]
        default: []
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
        case Self.mainnet.magicBytes:
            self = .mainnet
        case Self.testnet.magicBytes:
            self = .testnet
        /*case Self.signet.magicBytes:
            self = .signet*/
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
