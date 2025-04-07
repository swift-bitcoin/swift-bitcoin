import Foundation
import BitcoinBase
import BitcoinCrypto

infix operator ~: AssignmentPrecedence

// MARK: - Identity A

public func ~<X: ExpB>(lhs: @escaping (_ x: X) -> A_<X>, rhs: X) -> A_<X> { lhs(rhs) }
public func A<X: ExpB>(_ x: X) -> A_<X> { A_(x) }

/// Semantics: `X (identities)`; Miniscript: `a:X`; BitcoinScript: `TOALTSTACK [X] FROMALTSTACK`.
public struct A_<X: ExpB>: ExpW {
    public init(_ x: X) { self.x = x }
    let x: X

    public var compiled: [ScriptOp] {
        [.toAltStack] + x.compiled + [.fromAltStack]
    }

    public var description: String {
        "a:\(x)"
    }
}

extension A_: ModD where X: ModD { }
extension A_: ModU where X: ModU { }

// MARK: - Identity S

public func ~<X: ExpB>(lhs: @escaping (_ x: X) -> S_<X>, rhs: X) -> S_<X> { lhs(rhs) }
public func S<X: ExpB>(_ x: X) -> S_<X> { S_(x) }

/// Semantics: `X (identities)`; Miniscript: `s:X`; BitcoinScript: `SWAP [X]`.
public struct S_<X: ExpB>: ExpW {
    public init(_ x: X) { self.x = x }
    let x: X

    public var compiled: [ScriptOp] {
        [.swap] + x.compiled
    }

    public var description: String {
        let xDescription = x.description
        if let _ = try? /[astcdvjnlu]*\:/.prefixMatch(in: xDescription) {
            return "s\(xDescription)"
        } else {
            return "s:\(xDescription)"
        }
    }
}

extension S_: ModD where X: ModD { }
extension S_: ModU where X: ModU { }

// MARK: - Identity T

public func ~<X: ExpV>(lhs: @escaping (_ x: X) -> T_<X>, rhs: X) -> T_<X> { lhs(rhs) }
public func T<X: ExpV>(_ x: X) -> T_<X> { T_(x) }

/// Semantics: `X (identities)`; Miniscript: `t:X = and_v(X,1)`; BitcoinScript: `[X] 1`.
public struct T_<X: ExpV>: ExpB, ModD, ModU {
    public init(_ x: X) { self.x = x }
    let x: X
    public var compiled: [ScriptOp] { AndV(x, One()).compiled }

    public var description: String {
        let xDescription = x.description
        if let _ = try? /[astcdvjnlu]*\:/.prefixMatch(in: xDescription) {
            return "t\(xDescription)"
        } else {
            return "t:\(xDescription)"
        }
    }

}

extension T_: ModZ where X: ModZ { }
extension T_: ModO where X: ModO { }
extension T_: ModN where X: ModN { }

// MARK: - Identity C

public func ~<X: ExpK>(lhs: @escaping (_ x: X) -> C_<X>, rhs: X) -> C_<X> { lhs(rhs) }
public func C<X: ExpK>(_ x: X) -> C_<X> { C_(x) }

/// Semantics: `C (identities)`; Miniscript: `c:X`; BitcoinScript: `[X] CHECKSIG`.
public struct C_<X: ExpK>: ExpB, ModU {
    public init(_ x: X) { self.x = x }
    let x: X

    public var compiled: [ScriptOp] {
        x.compiled + [.checkSig]
    }

    public var description: String {
        let xDescription = x.description
        if let _ = try? /[astcdvjnlu]*\:/.prefixMatch(in: xDescription) {
            return "c\(xDescription)"
        } else {
            return "c:\(xDescription)"
        }
    }

}

extension C_: ModO where X: ModO { }
extension C_: ModN where X: ModN { }
extension C_: ModD where X: ModD { }

// MARK: - Identity D

public func ~<X: ExpV>(lhs: @escaping (_ x: X) -> D_<X>, rhs: X) -> D_<X> { lhs(rhs) }
public func D<X: ExpV>(_ x: X) -> D_<X> { D_(x) }

/// Semantics: `X (identities)`; Miniscript: `d:X`; BitcoinScript: `DUP IF [X] ENDIF`.
public struct D_<X: ExpV>: ExpB, ModO, ModN, ModD, ModU {
    // TODO: ModU conformance should be tapscript only. Potential solution: duplicate struct definition?

    public init(_ x: X) { self.x = x }
    let x: X

    public var compiled: [ScriptOp] {
        [.dup, .if] + x.compiled + [.endIf]
    }

    public var description: String {
        let xDescription = x.description
        if let _ = try? /[astcdvjnlu]*\:/.prefixMatch(in: xDescription) {
            return "d\(xDescription)"
        } else {
            return "d:\(xDescription)"
        }
    }

}

// MARK: - Identity V

public func ~<X: ExpB>(lhs: @escaping (_ x: X) -> V_<X>, rhs: X) -> V_<X> { lhs(rhs) }
public func V<X: ExpB>(_ x: X) -> V_<X> { V_(x) }

/// Semantics: `X (identities)`; Miniscript: `v:X`; BitcoinScript: `[X] VERIFY (or VERIFY version of last opcode in [X])`.
public struct V_<X: ExpB>: ExpV {

    public init(_ x: X) { self.x = x }
    let x: X

    public var compiled: [ScriptOp] {
        var xCompiled = x.compiled
        if let lastOp = xCompiled.popLast() {
            switch lastOp {
            case .checkSig:
                return xCompiled + [.checkSigVerify]
            case .checkMultiSig:
                return xCompiled + [.checkMultiSigVerify]
            case .equal:
                return xCompiled + [.equalVerify]
            case .numEqual:
                return xCompiled + [.numEqualVerify]
            default:
                return xCompiled + [lastOp, .verify]
            }
        } else {
            return [.verify]
        }
    }

    public var description: String {
        let xDescription = x.description
        if let _ = try? /[astcdvjnlu]*\:/.prefixMatch(in: xDescription) {
            return "v\(xDescription)"
        } else {
            return "v:\(xDescription)"
        }
    }
}

extension V_: ModZ where X: ModZ { }
extension V_: ModO where X: ModO { }
extension V_: ModN where X: ModN { }

// MARK: - Identity J

public func ~<X: ExpB>(lhs: @escaping (_ x: X) -> J_<X>, rhs: X) -> J_<X> { lhs(rhs) }
public func J<X: ExpB>(_ x: X) -> J_<X> { J_(x) }

/// Semantics: `X (identities)`; Miniscript: `j:X`; BitcoinScript: `SIZE 0NOTEQUAL IF [X] ENDIF`.
public struct J_<X: ExpB>: ExpB, ModN, ModD {
    public init(_ x: X) { self.x = x }
    let x: X

    public var compiled: [ScriptOp] {
        [.size, .zeroNotEqual, .if] + x.compiled + [.endIf]
    }

    public var description: String {
        let xDescription = x.description
        if let _ = try? /[astcdvjnlu]*\:/.prefixMatch(in: xDescription) {
            return "j\(xDescription)"
        } else {
            return "j:\(xDescription)"
        }
    }

}

extension J_: ModO where X: ModO { }
extension J_: ModU where X: ModU { }

// MARK: - Identity N

public func ~<X: ExpB>(lhs: @escaping (_ x: X) -> N_<X>, rhs: X) -> N_<X> { lhs(rhs) }
public func N<X: ExpB>(_ x: X) -> N_<X> { N_(x) }

/// Semantics: `X (identities)`; Miniscript: `n:X`; BitcoinScript: `[X] 0NOTEQUAL`.
public struct N_<X: ExpB>: ExpB, ModU {
    public init(_ x: X) { self.x = x }
    let x: X

    public var compiled: [ScriptOp] {
        x.compiled + [.zeroNotEqual]
    }

    public var description: String {
        let xDescription = x.description
        if let _ = try? /[astcdvjnlu]*\:/.prefixMatch(in: xDescription) {
            return "n\(xDescription)"
        } else {
            return "n:\(xDescription)"
        }
    }
}

extension N_: ModZ where X: ModZ { }
extension N_: ModO where X: ModO { }
extension N_: ModN where X: ModN { }
extension N_: ModD where X: ModD { }

// MARK: - Identity L

public func ~<X: ExpB>(lhs: @escaping (_ x: X) -> L_<X>, rhs: X) -> L_<X> { lhs(rhs) }
public func L<X: ExpB>(_ x: X) -> L_<X> { L_(x) }

/// Semantics: `X (identities)`; Miniscript: `l:X = or_i(0,X)`; BitcoinScript: `IF 0 ELSE [X] ENDIF`.
public struct L_<X: ExpB>: ExpB, ModD {
    public init(_ x: X) { self.x = x }
    let x: X
    public var compiled: [ScriptOp] { OrI(Zero(), x).compiled }

    public var description: String {
        let xDescription = x.description
        if let _ = try? /[astcdvjnlu]*\:/.prefixMatch(in: xDescription) {
            return "l\(xDescription)"
        } else {
            return "l:\(xDescription)"
        }
    }

}

extension L_: ModO where X: ModZ { }
extension L_: ModU where X: ModU { }

// MARK: - Identity U

public func ~<X: ExpB>(lhs: @escaping (_ x: X) -> U_<X>, rhs: X) -> U_<X> { lhs(rhs) }
public func U<X: ExpB>(_ x: X) -> U_<X> { U_(x) }

/// Semantics: `X (identities)`; Miniscript: `u:X = or_i(X,0)`; BitcoinScript: `IF [X] ELSE 0 ENDIF`.
public struct U_<X: ExpB>: ExpB, ModD {
    public init(_ x: X) { self.x = x }
    let x: X
    public var compiled: [ScriptOp] { OrI(x, Zero()).compiled }

    public var description: String {
        let xDescription = x.description
        if let _ = try? /[astcdvjnlu]*\:/.prefixMatch(in: xDescription) {
            return "u\(xDescription)"
        } else {
            return "u:\(xDescription)"
        }
    }

}

extension U_: ModO where X: ModZ { }
extension U_: ModU where X: ModU { }
