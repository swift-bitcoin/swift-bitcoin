import Foundation

enum WalletNetwork {
    case main, test

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
