import Foundation
import LibSECP256k1

/// Requires global signing context to be initialized.
public func checkSecretKey(_ secretKey: Data) -> Bool {
    let secretKey = [UInt8](secretKey)
    return secp256k1_ec_seckey_verify(eccSigningContext, secretKey) != 0
}
