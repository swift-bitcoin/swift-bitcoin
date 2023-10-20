import Foundation

public struct ScriptConfigurarion {
    public var verifyNullDummy = true
    public var verifyLowSSignature = true

    public static let standard = ScriptConfigurarion()
    public static let mandatory = ScriptConfigurarion(
        verifyNullDummy: false,
        verifyLowSSignature: false
    )
}
