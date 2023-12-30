import Foundation

public enum WalletNetwork: String {
    case main, test

    /// Base58-check version for encoding public keys into addresses.
    var base58Version: Int {
        switch self {
        case .main: 0x00
        case .test: 0x6f // 111
        }
    }

    /// BIP13: Base58-check version for encoding scripts into addresses.
    var base58VersionScript: Int {
        switch self {
        case .main: 0x05
        case .test: 0xc4 // 196
        }
    }

    /// Little-endian
    var hdKeyVersionPrivate: Int {
        switch self {
        case .main: Self.mainHDKeyVersionPrivate
        case .test: Self.testHDKeyVersionPrivate
        }
    }

    /// Little-endian
    var hdKeyVersionPublic: Int {
        switch self {
        case .main: Self.mainHDKeyVersionPublic
        case .test: Self.testHDKeyVersionPublic
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
