import Foundation
import BitcoinCrypto

extension ECDSASignature {

    /// A signature with sighash type extension.
    public struct Extended: Equatable, Sendable {

        public init(_ sig: ECDSASignature, sighashType: SighashType) {
            self.sig = sig
            self.sighashType = sighashType
        }

        public let sig: ECDSASignature
        public let sighashType: SighashType
    }
}

extension ECDSASignature.Extended {

    package init?(_ data: Data, skipCheck: Bool = false) {
        guard let last = data.last, let sig = ECDSASignature(data.dropLast()) else {
            return nil
        }
        self.sig = sig
        let sighashType = SighashType(unchecked: last)
        if !skipCheck && !sighashType.isDefined {
            return nil
        }
        self.sighashType = sighashType
    }

    public var data: Data {
        sig.data + sighashType.binaryData
    }
}
