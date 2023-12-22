import Foundation
import ECCHelper

func getPublicKey(secretKey: Data, compress: Bool = true) -> Data {
    let secretKeyPtr = secretKey.withUnsafeBytes { $0.bindMemory(to: UInt8.self).baseAddress! }
    
    let publicKey: [UInt8] = .init(unsafeUninitializedCapacity: PUBKEY_MAX_LEN) { buf, len in
        let successOrError = getPublicKey(buf.baseAddress, &len, secretKeyPtr, compress ? 1 : 0)
        precondition(len == PUBKEY_MAX_LEN || len == PUBKEY_COMPRESSED_LEN, "Key must be either 65 (uncompressed) or 33 (compressed) bytes long.")
        precondition(successOrError == 1, "Computation of internal key failed.")
    }
    return Data(publicKey)
}
