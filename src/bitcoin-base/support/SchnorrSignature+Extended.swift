import Foundation
import BitcoinCrypto

extension SchnorrSignature {

    /// A signature with sighash type extension.
    public struct Extended: Equatable, Sendable {

        public init(_ sig: SchnorrSignature, sighashType: SighashType? = nil) {
            self.sig = sig
            self.sighashType = sighashType
        }
        
        public let sig: SchnorrSignature
        public let sighashType: SighashType?
    }
}

extension SchnorrSignature.Extended {

    init(_ data: Data) throws(ScriptError) {
        var data = data
        let sighashType: SighashType?
        if data.count == ECDSASignature.schnorrSignatureExtendedLength, let sighashValue = data.popLast(), let maybeHashType = SighashType(sighashValue) {
            // If the sig is 65 bytes long, return sig[64] ≠ 0x00 and Verify(q, hashTapSighash(0x00 || SigMsg(sig[64], 0)), sig[0:64]).
            sighashType = maybeHashType
        } else if data.count == SchnorrSignature.schnorrSignatureLength {
            // If the sig is 64 bytes long, return Verify(q, hashTapSighash(0x00 || SigMsg(0x00, 0)), sig), where Verify is defined in BIP340.
            sighashType = SighashType?.none
        } else {
            // Otherwise, fail.
            throw ScriptError.invalidSchnorrSignatureFormat
        }
        guard let sig = SchnorrSignature(data) else {
            throw ScriptError.invalidSchnorrSignature
        }
        self.sig = sig
        self.sighashType = sighashType
    }

    public var data: Data {
        sig.data + sighashType.data
    }
}
