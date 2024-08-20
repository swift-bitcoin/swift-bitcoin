import Foundation
import BitcoinCrypto

extension PublicKey {
    /// Self is an x-only internal public key.
    func tapTweak(merkleRoot: Data) -> Data {
        taggedHash(tag: "TapTweak", payload: xOnlyData.x + merkleRoot)

    }

    public func taprootOutputKey(merkleRoot: Data = .init()) -> PublicKey {
        tweakXOnly(tapTweak(merkleRoot: merkleRoot))
    }
}
