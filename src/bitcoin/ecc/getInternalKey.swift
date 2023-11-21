import Foundation
import ECCHelper

func getInternalKey(secretKey: Data) -> Data {
    let secretKeyPtr = secretKey.withUnsafeBytes { $0.bindMemory(to: UInt8.self).baseAddress! }
    
    let internalKey: [UInt8] = .init(unsafeUninitializedCapacity: 32) { buf, len in
        let successOrError = getInternalKey(buf.baseAddress, &len, secretKeyPtr)
        precondition(len == 32, "Key must be 32 bytes long.")
        precondition(successOrError == 1, "Computation of internal key failed.")
    }
    return Data(internalKey)
}
