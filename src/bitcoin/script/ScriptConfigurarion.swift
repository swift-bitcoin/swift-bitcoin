import Foundation

public struct ScriptConfigurarion {
    public var checkNullDummy = true
    public var checkLowS = true
    public var checkStrictDER = true
    public var checkStrictEncoding = true

    public static let standard = ScriptConfigurarion()
    public static let mandatory = ScriptConfigurarion(
        checkNullDummy: false,
        checkLowS: false,
        checkStrictDER: false,
        checkStrictEncoding: false
    )
}
