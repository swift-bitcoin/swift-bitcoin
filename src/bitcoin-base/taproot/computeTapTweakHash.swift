import Foundation
import BitcoinCrypto

/// Internal key is an x-only public key.
public func computeTapTweakHash(internalKey: Data, merkleRoot: Data) -> Data {
    taggedHash(tag: "TapTweak", payload: internalKey + merkleRoot)
}
