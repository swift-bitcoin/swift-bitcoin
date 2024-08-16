import Foundation
import BitcoinCrypto

/// Internal key is an x-only public key.
public func computeControlBlock(internalKey: Data, merkleRoot: Data, leafVersion: Int, path: Data) -> Data {
    let (_, outputPubKeyYParity) = tweakXOnlyPublicKey(internalKey, tweak: computeTapTweakHash(internalKey: internalKey, merkleRoot: merkleRoot))
    let outputPubKeyYParityBit = UInt8(outputPubKeyYParity ? 1 : 0)
    let controlByte = withUnsafeBytes(of: UInt8(leafVersion) + outputPubKeyYParityBit) { Data($0) }
    return controlByte + internalKey + path
}
