import Foundation

/// Internal key is an x-only public key.
public func computeTapTweakHash(internalKey: Data, merkleRoot: Data?) -> Data {
    var joined = internalKey
    if let merkleRoot {
        joined += merkleRoot
    }
    return taggedHash(tag: "TapTweak", payload: joined)
}
