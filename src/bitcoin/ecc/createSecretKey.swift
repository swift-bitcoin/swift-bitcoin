import Foundation
import ECCHelper
import LibSECP256k1

public func createSecretKey2() -> Data {
    let secretKey: [UInt8] = .init(unsafeUninitializedCapacity: 32) { buf, len in
        let successOrError = createSecretKey(eccSigningContext, getRandBytesExtern(_:_:), buf.baseAddress, &len)
        precondition(len == 32, "Key must be 32 bytes long.")
        precondition(successOrError == 1, "Computation of internal key failed.")
    }
    return Data(secretKey)
}

public func createSecretKey() -> Data {
    guard let eccSigningContext else { preconditionFailure() }
    var secretKey: [UInt8]
    repeat {
        secretKey = getRandBytes(32)
    } while secp256k1_ec_seckey_verify(eccSigningContext, secretKey) == 0
    return Data(secretKey)
}
