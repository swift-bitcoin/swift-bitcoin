import Foundation
import BitcoinCrypto

/// A signature with sighash type extension.
public struct ExtendedSignature {

    public init(_ signature: Signature, _ sighashType: SighashType?) {
        self.signature = signature
        self.sighashType = sighashType
    }

    init?(_ data: Data, skipCheck: Bool = false) {
        guard let last = data.last, let signature = Signature(data.dropLast()) else {
            return nil
        }
        self.signature = signature
        let sighashType = SighashType(rawValue: last)
        if !skipCheck && !sighashType.isDefined {
            return nil
        }
        self.sighashType = sighashType
    }

    init(schnorrData: Data) throws {
        var sigTmp = schnorrData
        let sighashType: SighashType?
        if sigTmp.count == Signature.schnorrSignatureExtendedLength, let rawValue = sigTmp.popLast(), let maybeHashType = SighashType(rawValue) {
            // If the sig is 65 bytes long, return sig[64] ≠ 0x00 and Verify(q, hashTapSighash(0x00 || SigMsg(sig[64], 0)), sig[0:64]).
            sighashType = maybeHashType
        } else if sigTmp.count == Signature.schnorrSignatureLength {
            // If the sig is 64 bytes long, return Verify(q, hashTapSighash(0x00 || SigMsg(0x00, 0)), sig), where Verify is defined in BIP340.
            sighashType = SighashType?.none
        } else {
            // Otherwise, fail.
            throw ScriptError.invalidSchnorrSignatureFormat
        }
        guard let signature = Signature(sigTmp, type: .schnorr) else {
            throw ScriptError.invalidSchnorrSignature
        }
        self.signature = signature
        self.sighashType = sighashType
    }

    public let signature: Signature
    public let sighashType: SighashType?

    public var data: Data {
        signature.data + sighashType.data
    }
}
