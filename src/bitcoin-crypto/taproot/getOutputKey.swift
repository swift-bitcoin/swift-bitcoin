import Foundation

/// Internal key is an x-only public key.
public func getOutputKey(internalKey: Data, merkleRoot: Data? = .none) -> Data {
    let (outputKey, _) = createTapTweak(internalKey: internalKey, merkleRoot: merkleRoot)
    return outputKey
}

public func getOutputKey(secretKey: Data, merkleRoot: Data? = .none) -> Data {
    getOutputKey(internalKey: getInternalKey(secretKey: secretKey), merkleRoot: merkleRoot)
}
