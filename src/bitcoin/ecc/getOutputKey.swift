import Foundation

public func getOutputKey(secretKey: Data, merkleRoot: Data? = .none) -> Data {
    getOutputKey(internalKey: getInternalKey(secretKey: secretKey), merkleRoot: merkleRoot)
}

func getOutputKey(internalKey: Data, merkleRoot: Data? = .none) -> Data {
    let (outputKey, _) = createTapTweak(publicKey: internalKey, merkleRoot: merkleRoot)
    return outputKey
}
