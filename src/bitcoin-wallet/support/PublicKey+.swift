import Foundation
import BinaryParsing
import BitcoinCrypto

extension PublicKey {

    /// Forces the parity to be even-y for uses in ``TaprootAddress``.
    var xOnlyNormalized: Self? {
        if hasEvenY {
            self
        } else if let normalized = PublicKey(xOnly: xOnlyData) {
            normalized
        } else {
            .none
        }
    }

    var id: Data {
        Data(Hash160.hash(data: data))
    }

    package var fingerprint: Int {
        let fingerprint32 = try! id.withParserSpan { input in
            try UInt32(parsingLittleEndian: &input)
        }
        return Int(fingerprint32)
    }
}
