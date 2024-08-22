import Foundation
import LibSECP256k1

// TODO: Take what's useful and clear this file up.
/// These extensions are not currently used although they might be useful some day.
private extension SecretKey {

    /// Requires global signing context to be initialized.
    func getPublicKey(compress: Bool = true) -> Data {

        let secretKey = [UInt8](data)

        var pubkey = secp256k1_pubkey()
        guard secp256k1_ec_pubkey_create(eccSigningContext, &pubkey, secretKey) != 0 else {
            preconditionFailure()
        }

        var publicKeyBytes = [UInt8](repeating: 0, count: compress ? PublicKey.compressedLength : PublicKey.uncompressedLength)
        var publicKeyBytesCount = publicKeyBytes.count
        guard secp256k1_ec_pubkey_serialize(secp256k1_context_static, &publicKeyBytes, &publicKeyBytesCount, &pubkey, UInt32(compress ? SECP256K1_EC_COMPRESSED : SECP256K1_EC_UNCOMPRESSED)) != 0 else {
            preconditionFailure()
        }
        assert(compress && publicKeyBytesCount == PublicKey.compressedLength || (!compress && publicKeyBytesCount == PublicKey.uncompressedLength))

        return Data(publicKeyBytes)
    }
}
