import Foundation

public enum WalletNetwork: String {
    case main, test, regtest

    /// Bech32 human readable part (prefix).
    var bech32HRP: String {
        switch self {
        case .main: "bc"
        case .test: "tb"
        case .regtest: "bcrt"
        }
    }

    /// Base58-check version for encoding public keys into addresses.
    var base58Version: Int {
        switch self {
        case .main: 0x00
        case .test,.regtest: 0x6f // 111
        }
    }

    /// BIP13: Base58-check version for encoding scripts into addresses.
    var base58VersionScript: Int {
        switch self {
        case .main: 0x05
        case .test, .regtest: 0xc4 // 196
        }
    }

    /// For use when encoding/decoding secret keys.
    var base58VersionPrivate: Int {
        switch self {
        case .main: 0x80 // 128
        case .test,.regtest: 0xef // 239
        }
    }

    /// Little-endian
    var hdKeyVersionPrivate: Int {
        switch self {
        case .main: Self.mainHDKeyVersionPrivate
        case .test, .regtest: Self.testHDKeyVersionPrivate
        }
    }

    /// Little-endian
    var hdKeyVersionPublic: Int {
        switch self {
        case .main: Self.mainHDKeyVersionPublic
        case .test, .regtest: Self.testHDKeyVersionPublic
        }
    }

    static let mainHDKeyVersionPrivate = 0x0488ade4
    static let mainHDKeyVersionPublic = 0x0488b21e
    static let testHDKeyVersionPrivate = 0x04358394
    static let testHDKeyVersionPublic = 0x043587cf

    static func fromHDKeyVersion(_ versionValue: UInt32) -> Self? {
        switch Int(versionValue) {
        case mainHDKeyVersionPrivate, mainHDKeyVersionPublic:
            .main
        case testHDKeyVersionPrivate, testHDKeyVersionPublic:
            .test
        default:
            .none
        }
    }
}
