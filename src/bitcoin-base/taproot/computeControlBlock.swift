import Foundation
import BitcoinCrypto

/// Use from tests.
/// Internal key is an x-only public key.
func computeControlBlock(internalKey internalKeyData: Data, merkleRoot: Data, leafVersion: Int, path: Data) -> Data {
    guard let internalKey = PublicKey(xOnly: internalKeyData) else {
        preconditionFailure("Wrong xOnly public key length")
    }
    let outputKey = internalKey.taprootOutputKey(merkleRoot: merkleRoot)
    let outputKeyYParityBit = UInt8(outputKey.hasEvenY ? 0 : 1)
    let controlByte = withUnsafeBytes(of: UInt8(leafVersion) + outputKeyYParityBit) { Data($0) }
    return controlByte + internalKeyData + path
}
