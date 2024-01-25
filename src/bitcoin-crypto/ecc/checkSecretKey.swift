import Foundation
import LibSECP256k1

/// Requires global signing context to be initialized.
public func checkSecretKey(_ secretKeyData: Data) -> Bool {
    guard let eccSigningContext else { preconditionFailure() }

    let secretKey = [UInt8](secretKeyData)
    return secp256k1_ec_seckey_verify(eccSigningContext, secretKey) != 0
}
