import Foundation
import BitcoinBase
import BitcoinCrypto

/// Semantics: `false`; Miniscript: `0`;  BitcoinScript: `0`
public struct Zero: ExpB, ModZ, ModU, ModD {
    public init() { }

    public var compiled: [ScriptOp] {
        [.zero]
    }

    public var description: String { "0" }
}

/// Semantics: `true`; Miniscript: `1`; BitcoinScript: `1`.
public struct One: ExpB, ModZ, ModU {
    public init() { }

    public var compiled: [ScriptOp] {
        [.constant(1)]
    }

    public var description: String { "1" }
}

/// Semantics: `check(key)`; Miniscript: `pk_k(key)`; BitcoinScript: `<key>`.
public struct PK_K: ExpK, ModO, ModN, ModD, ModU {
    public init(_ key: PubKey) { self.key = key }
    let key: PubKey

    public var compiled: [ScriptOp] {
        // For tapscript should be key.xOnlyData
        [.pushBytes(key.compressedData!)]
    }

    public var description: String {
        "pk_k(\(key.compressedData!.hex))"
    }
}

/// Semantics: `check(key)`; Miniscript: `pk_h(key)`; BitcoinScript: `DUP HASH160 <HASH160(key)> EQUALVERIFY`.
public struct PK_H: ExpK, ModN, ModD, ModU {
    public init(_ key: PubKey) { self.key = key }
    let key: PubKey

    public var compiled: [ScriptOp] {
        guard let keyData = key.compressedData else { // For tapscript should be key.xOnlyData
            preconditionFailure()
        }
        let hash = Data(BitcoinCrypto.Hash160.hash(data: keyData))
        return [.dup, .hash160,  .pushBytes(hash), .equalVerify]
    }

    public var description: String {
        "pk_h(\(key.compressedData!.hex))"
    }
}

/// Semantics: `check(key)`; Miniscript: `pk(key) = c:pk_k(key)`; BitcoinScript: `<key> CHECKSIG`.
public struct PK: ExpB, ModO, ModN, ModD, ModU {
    public init(_ key: PubKey) { self.key = key }
    let key: PubKey
    public var compiled: [ScriptOp] { C_(PK_K(key)).compiled }

    public var description: String {
        "pk(\(key.compressedData!.hex))"
    }
}

/// Semantics: `check(key)`; Miniscript: `pkh(key) = c:pk_h(key)`; BitcoinScript: `DUP HASH160 <HASH160(key)> EQUALVERIFY CHECKSIG`.
public struct PKH: ExpB, ModN, ModD, ModU {
    public init(_ key: PubKey) { self.key = key }
    let key: PubKey
    public var compiled: [ScriptOp] { C_(PK_H(key)).compiled }

    public var description: String {
        "pkh(\(key.compressedData!.hex))"
    }
}

/// Semantics: `nSequence ≥ n (and compatible)`; Miniscript: `older(n)`; BitcoinScript: `<n> CHECKSEQUENCEVERIFY`.
public struct Older: ExpB, ModZ {
    public init(_ n: Int) { self.n = n }
    let n: Int

    public var compiled: [ScriptOp] {
        [.encodeMinimally(n), .checkSequenceVerify]
    }

    public var description: String {
        "older(\(n))"
    }
}

/// Semantics: `nLockTime ≥ n (and compatible)`; Miniscript: `after(n)`; BitcoinScript: `<n> CHECKLOCKTIMEVERIFY`.
public struct After: ExpB, ModZ {
    public init(_ n: Int) { self.n = n }
    let n: Int

    public var compiled: [ScriptOp] {
        [.encodeMinimally(n), .checkLockTimeVerify]
    }

    public var description: String {
        "after(\(n))"
    }
}

/// Semantics: `len(x) = 32 and SHA256(x) = h`; Miniscript: `sha256(h)`; BitcoinScript: `SIZE <20> EQUALVERIFY SHA256 <h> EQUAL`.
public struct SHA256: ExpB, ModO, ModN, ModD, ModU {

    public init(_ h: Data) {
        precondition(h.count == BitcoinCrypto.SHA256.Digest.byteCount)
        self.h = h
    }
    let h: Data

    public var compiled: [ScriptOp] {
        [.size, .encodeMinimally(0x20), .equalVerify, .sha256, .pushBytes(h), .equal]
    }

    public var description: String {
        "sha256(\(h.hex))"
    }
}

/// Semantics: `len(x) = 32 and HASH256(x) = h`; Miniscript: `hash256(h)`; BitcoinScript: `SIZE <20> EQUALVERIFY HASH256 <h> EQUAL`.
public struct Hash256: ExpB, ModO, ModN, ModD, ModU {

    public init(_ h: Data) {
        precondition(h.count == BitcoinCrypto.Hash256.Digest.byteCount)
        self.h = h
    }

    let h: Data

    public var compiled: [ScriptOp] {
        [.size, .encodeMinimally(0x20), .equalVerify, .hash256, .pushBytes(h), .equal]
    }

    public var description: String {
        "hash256(\(h.hex))"
    }
}

/// Semantics: `len(x) = 32 and RIPEMD160(x) = h`; Miniscript: `ripemd160(h)`; BitcoinScript: `SIZE <20> EQUALVERIFY RIPEMD160 <h> EQUAL`.
public struct RIPEMD160: ExpB, ModO, ModN, ModD, ModU {

    public init(_ h: Data) {
        precondition(h.count == BitcoinCrypto.RIPEMD160.Digest.byteCount)
        self.h = h
    }

    let h: Data

    public var compiled: [ScriptOp] {
        [.size, .encodeMinimally(0x20), .equalVerify, .ripemd160, .pushBytes(h), .equal]
    }

    public var description: String {
        "ripemd160(\(h.hex))"
    }
}

/// Semantics: `len(x) = 32 and HASH160(x) = h`; Miniscript: `hash160(h)`; BitcoinScript: `SIZE <20> EQUALVERIFY HASH160 <h> EQUAL`.
public struct Hash160: ExpB, ModO, ModN, ModD, ModU {

    public init(_ h: Data) {
        precondition(h.count == BitcoinCrypto.Hash160.Digest.byteCount)
        self.h = h
    }

    let h: Data

    public var compiled: [ScriptOp] {
        [.size, .encodeMinimally(0x20), .equalVerify, .hash160, .pushBytes(h), .equal]
    }

    public var description: String {
        "hash160(\(h.hex))"
    }
}

/// Semantics: `(X and Y) or Z`; Miniscript: `andor(X,Y,Z)`; BitcoinScript: `[X] NOTIF [Z] ELSE [Y] ENDIF`.
public struct AndOr<X: ExpB, Y: ExpBKV, Z: ExpBKV>: ExpBKV {
    private init(x: X, y: Y, z: Z) { self.x = x; self.y = y; self.z = z }

    let x: X; let y: Y; let z: Z

    public var compiled: [ScriptOp] {
        x.compiled + [.notIf] + z.compiled + [.else] + y.compiled + [.endIf]
    }

    public var description: String {
        "andor(\(x),\(y),\(z))"
    }
}

extension AndOr: ExpB where Y: ExpB, Z: ExpB {
    public init(_ x: X, _ y: Y, _ z: Z) { self.init(x: x, y: y, z: z) }
}

extension AndOr: ExpK where Y: ExpK, Z: ExpK {
    public init(_ x: X, _ y: Y, _ z: Z) { self.init(x: x, y: y, z: z) }
}

extension AndOr: ExpV where Y: ExpV, Z: ExpV {
    public init(_ x: X, _ y: Y, _ z: Z) { self.init(x: x, y: y, z: z) }
}

extension AndOr: ModZ where X: ModZ, Y: ModZ, Z: ModZ { }
extension AndOr: ModO where X: ModZ, Y: ModO, Z: ModO { }
// TODO: Work around conflicting conformances :(
// extension AndOr: ModO where X: ModO, Y: ModZ, Z: ModZ { }
extension AndOr: ModU where Y: ModU, Z: ModU { }
extension AndOr: ModD where Z: ModD { }

/// Semantics: `X and Y`; Miniscript: `and_v(X,Y)`; Bitcoin Script: `[X] [Y]`.
public struct AndV<X: ExpV, Y: ExpBKV>: ExpBKV {
    public init(_ x: X, _ y: Y) { self.x = x; self.y = y }
    let x: X, y: Y

    public var compiled: [ScriptOp] {
        x.compiled + y.compiled
    }

    public var description: String {
        "and_v(\(x),\(y))"
    }
}

extension AndV: ExpB where Y: ExpB { }
extension AndV: ExpK where Y: ExpK { }
extension AndV: ExpV where Y: ExpV { }

extension AndV: ModZ where X: ModZ, Y: ModZ { }
extension AndV: ModO where X: ModZ, Y: ModO { }
// TODO: Work around conflicting conformances :(
// extension AndV: ModO where X: ModO, Y: ModZ { }
extension AndV: ModN where X: ModN { }
// TODO: Work around conflicting conformances :(
// extension AndV: ModN where X: ModZ, Y: ModN { }
extension AndV: ModU where Y: ModU { }

/// Semantics: `X and Y`; Miniscript: `and_b(X,Y)`; Bitcoin Script: `[X] [Y] BOOLAND`.
public struct AndB<X: ExpB, Y: ExpW>: ExpB, ModU {
    public init(_ x: X, _ y: Y) { self.x = x; self.y = y }
    let x: X, y: Y

    public var compiled: [ScriptOp] {
        x.compiled + y.compiled + [.boolAnd]
    }

    public var description: String {
        "and_b(\(x),\(y))"
    }
}

extension AndB: ModZ where X: ModZ, Y: ModZ { }
extension AndB: ModO where X: ModZ, Y: ModO { }
// TODO: Work around conflicting conformances :(
// extension AndB: ModO where X: ModO, Y: ModZ { }
extension AndB: ModN where X: ModN { }
// TODO: Work around conflicting conformances :(
// extension AndB: ModN where X: ModZ, Y: ModN { }
extension AndB: ModD where X: ModD, Y: ModD { }

/// Semantics: `X and Y`; Miniscript: `and_n(X,Y) = andor(X,Y,0)`; Bitcoin Script: `[X] NOTIF 0 ELSE [Y] ENDIF`.
public struct AndN<X: ExpB, Y: ExpB>: ExpB {
    public init(_ x: X, _ y: Y) { self.x = x; self.y = y }
    let x: X, y: Y
    public var compiled: [ScriptOp] { AndOr(x, y, Zero()).compiled }

    public var description: String {
        "and_n(\(x),\(y))"
    }
}

/// Semantics: `X or Z`; Miniscript: `or_b(X,Z)`; BitcoinScript: `[X] [Z] BOOLOR`.
public struct OrB<X: ExpB & ModD, X_: ExpB & ModD_, Z: ExpW & ModD, Z_: ExpW & ModD_>: ExpB, ModD, ModU {

    public init(_ x: X, _ z: Z, _ dummyX: X_? = Never?.none, _ dummyZ: Z_? = Never?.none) {
        precondition(dummyX == nil)
        precondition(dummyZ == nil)
        self._x = x
        self._z = z
    }

    public init(_ x: X_, _ z: Z, _ dummyX: X? = Never?.none, _ dummyZ: Z_? = Never?.none) {
        precondition(dummyX == nil)
        precondition(dummyZ == nil)
        self.__x = x
        self._z = z
    }

    public init(_ x: X, _ z: Z_, _ dummyX: X_? = Never?.none, _ dummyZ: Z? = Never?.none) {
        precondition(dummyX == nil)
        precondition(dummyZ == nil)
        self._x = x
        self.__z = z
    }

    public init(_ x: X_, _ z: Z_, _ dummyX: X? = Never?.none, _ dummyZ: Z? = Never?.none) {
        precondition(dummyX == nil)
        precondition(dummyZ == nil)
        self.__x = x
        self.__z = z
    }

    private var _x: X? = nil
    private var __x: X_? = nil
    private var _z: Z? = nil
    private var __z: Z_? = nil

    var x: ExpB { _x ?? __x! }
    var z: ExpW { _z ?? __z! }

    public var compiled: [ScriptOp] {
        x.compiled + z.compiled + [.boolOr]
    }

    public var description: String {
        "or_b(\(x),\(z))"
    }
}

extension OrB: ModZ where X: ModZ, Z: ModZ { }
extension OrB: ModO where X: ModZ, Z: ModO { }
// TODO: Work around conflicting conformances :(
// extension OrB: ModO where X: ModO, Z: ModZ { }

/// Semantics: `X or Z`; Miniscript: `or_c(X,Z)`; BitcoinScript: `[X] NOTIF [Z] ENDIF`.
public struct OrC<X: ExpB, Z: ExpV>: ExpV {
    public init(_ x: X, _ z: Z) { self.x = x; self.z = z }
    let x: X, z: Z

    public var compiled: [ScriptOp] {
        x.compiled + [.notIf] + z.compiled + [.endIf]
    }

    public var description: String {
        "or_c(\(x),\(z))"
    }
}

extension OrC: ModZ where X: ModZ, Z: ModZ { }
extension OrC: ModO where X: ModO, Z: ModZ { }

/// Semantics: `X or Z`; Miniscript: `or_d(X,Z)`; BitcoinScript: `[X] IFDUP NOTIF [Z] ENDIF`.
public struct OrD<X: ExpB, Z: ExpB>: ExpB {
    public init(_ x: X, _ z: Z) { self.x = x; self.z = z }
    let x: X, z: Z

    public var compiled: [ScriptOp] {
        x.compiled + [.ifDup, .notIf] + z.compiled + [.endIf]
    }

    public var description: String {
        "or_d(\(x),\(z))"
    }
}

extension OrD: ModZ where X: ModZ, Z: ModZ { }
extension OrD: ModO where X: ModO, Z: ModZ { }
extension OrD: ModD where Z: ModD { }
extension OrD: ModU where Z: ModU { }

/// Semantics: `X or Z`; Miniscript: `or_i(X,Z)`; BitcoinScript: `IF [X] ELSE [Z] ENDIF`.
public struct OrI<X: ExpBKV, Z: ExpBKV>: ExpBKV {

    private init(x: X, z: Z) {
        self.x = x
        self.z = z
    }

    let x: X, z: Z

    public var compiled: [ScriptOp] {
        [.if] + x.compiled + [.else] + z.compiled + [.endIf]
    }

    public var description: String {
        "or_i(\(x),\(z))"
    }
}

extension OrI: ExpB where X: ExpB, Z: ExpB {
    public init(_ x: X, _ z: Z) { self.init(x: x, z: z) }
}

extension OrI: ExpK where X: ExpK, Z: ExpK {
    public init(_ x: X, _ z: Z) { self.init(x: x, z: z) }
}

extension OrI: ExpV where X: ExpV, Z: ExpV {
    public init(_ x: X, _ z: Z) { self.init(x: x, z: z) }
}

extension OrI: ModO where X: ModZ, Z: ModZ { }
extension OrI: ModU where X: ModU, Z: ModU { }
extension OrI: ModD where X: ModD { }
// TODO: Work around conflicting conformances :(
extension OrI: ModD_ where Z: ModD { }

/// Semantics: `X1 + ... + Xn = k`; Miniscript: `thresh(k,X1,...,Xn)`; BitcoinScript: `[X1] [X2] ADD ... [Xn] ADD ... <k> EQUAL`.
public struct Thresh<X0: ExpB, X1: ExpW, X2: ExpW, X3: ExpW>: ExpB, ModD, ModU {
    // TODO: Use paremeter packs!

    public init(_ k: Int, _ x0: X0, _ x1: X1, _ x2: X2, _ x3: X3) {
        precondition(k >= 1 && k <= 4)
        self.k = k
        self.x0 = x0
        self.x1 = x1
        self.x2 = x2
        self.x3 = x3
    }

    let k: Int
    let x0: X0
    let x1: X1, x2: X2, x3: X3

    public var compiled: [ScriptOp] {
        let k = UInt8(k)
        return x0.compiled + x1.compiled + [.add] + x2.compiled + [.add] + x3.compiled + [.add] + [.constant(k), .equal]
    }

    public var description: String {
        "thresh(\(k),\(x0),\(x1),\(x2),\(x3))"
    }
}

extension Thresh: ModZ where X0: ModZ, X1: ModZ, X2: ModZ, X3: ModZ { }
// TODO: Figure out conformance for ModO when _all are z except one is o_.

/// Semantics: `check(key1) + ... + check(keyn) = k (P2WSH only)`; Miniscript: `multi(k,key1,...,keyn)`; BitcoinScript: `<k> <key1> ... <keyn> <n> CHECKMULTISIG`.
public struct Multi: ExpB, ModN, ModD, ModU {

    public init(_ k: Int, _ keys: PubKey...) {
        precondition(keys.count >= 1 && keys.count <= UInt8.max)
        precondition(k >= 1)
        precondition(k <= keys.count)
        self.k = k
        self.keys = keys
    }

    let k: Int
    let keys: [PubKey]

    public var compiled: [ScriptOp] {
        let k = UInt8(k)
        let n = UInt8(keys.count)
        let keysPushBytes = keys
            .map {
                guard let keyData = $0.compressedData else { preconditionFailure() }
                return keyData
            }
            .map { ScriptOp.pushBytes($0) }
        return [.constant(k)] + keysPushBytes + [.constant(n), .checkMultiSig]
    }

    public var description: String {
        let keysHex = keys.map(\.compressedData!).map(\.hex).joined(separator: ",")
        return "multi(\(k),\(keysHex))"
    }
}

/// Semantics: `check(key1) + ... + check(keyn) = k (Tapscript only)`; Miniscript: `multi_a(k,key1,...,keyn)`; BitcoinScript: `<key1> CHECKSIG <key2> CHECKSIGADD ... <keyn> CHECKSIGADD <k> NUMEQUAL`.
public struct MultiA: ExpB, ModD, ModU {

    public init(_ k: Int, _ keys: PubKey...) {
        precondition(keys.count >= 1 && keys.count <= UInt8.max)
        precondition(k >= 1)
        precondition(k <= keys.count)
        self.k = k
        self.keys = keys
    }

    let k: Int
    let keys: [PubKey]

    public var compiled: [ScriptOp] {
        let k = UInt8(k)
        let keysPushBytes = keys.dropFirst()
            .map(\.xOnlyData)
            .flatMap {
                [ScriptOp.pushBytes($0), .checkSigAdd]
            }
        return [.pushBytes(keys[0].xOnlyData), .checkSig] + keysPushBytes + [.checkSigAdd, .constant(k), .numEqual]
    }

    public var description: String {
        let keysHex = keys.map(\.xOnlyData).map(\.hex).joined(separator: ",")
        return "multi_a(\(k),\(keysHex))"
    }
}
