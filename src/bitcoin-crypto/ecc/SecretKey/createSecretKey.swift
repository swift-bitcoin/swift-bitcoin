import Foundation
import LibSECP256k1

/// Requires global signing context to be initialized.
public func createSecretKey() -> Data {
    var secretKey: [UInt8]
    repeat {
        secretKey = getRandBytes(32)
    } while secp256k1_ec_seckey_verify(eccSigningContext, secretKey) == 0
    return Data(secretKey)
}
