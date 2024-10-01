import Foundation
import LibSECP256k1

/// Elliptic curve SECP256K1 secret key.
public struct SecretKey: Equatable, CustomStringConvertible {

    /// Uses global secp256k1 signing context.
    public init() {
        var bytes: [UInt8]
        repeat {
            bytes = getRandBytes(32)
        } while secp256k1_ec_seckey_verify(eccSigningContext, bytes) == 0
        self.data = Data(bytes)
    }

    /// Uses global secp256k1 signing context.
    public init?(_ data: Data) {
        guard data.count == Self.keyLength else {
            return nil
        }
        guard secp256k1_ec_seckey_verify(eccSigningContext, [UInt8](data)) != 0 else {
            return nil
        }
        self.data = data
    }

    public init?(_ hex: String) {
        guard let data = Data(hex: hex) else {
            return nil
        }
        self.init(data)
    }

    public let data: Data

    public var description: String {
        data.hex
    }

    public var publicKey: PublicKey {
        .init(self)
    }

    package var xOnlyPublicKey: PublicKey {
        .init(self, requireEvenY: true)
    }

    public func sign(_ message: String, signatureType: SignatureType = .ecdsa, recoverCompressedKeys: Bool = true) -> Signature? {
        .init(message: message, secretKey: self, type: signatureType, recoverCompressedKeys: recoverCompressedKeys)
    }

    public func sign(hash: Data, signatureType: SignatureType = .ecdsa, recoverCompressedKeys: Bool = true) -> Signature? {
        .init(hash: hash, secretKey: self, type: signatureType, recoverCompressedKeys: recoverCompressedKeys)
    }

    /// BIP32: Used to derive private keys. Requires global signing context to be initialized.
    public func tweak(_ tweak: Data) -> SecretKey {
        var secretKeyBytes = [UInt8](data)
        var tweak = [UInt8](tweak)

        let result = secp256k1_ec_seckey_tweak_add(eccSigningContext, &secretKeyBytes, &tweak)
        assert(result != 0)

        return SecretKey(Data(secretKeyBytes))!
    }

    /// There is no such thing as an x-only _secret_ key. This is to differenciate taproot x-only tweaking from BIP32 derivation EC tweaking. This functions is used in BIP341 tests.
    ///
    /// Requires global signing context to be initialized.
    ///
    public func tweakXOnly(_ tweak: Data) -> SecretKey {
        let secretKeyBytes = [UInt8](data)
        let tweak = [UInt8](tweak)

        var keypair = secp256k1_keypair()
        guard secp256k1_keypair_create(eccSigningContext, &keypair, secretKeyBytes) != 0 else {
            preconditionFailure()
        }

        // Tweak the keypair
        guard secp256k1_keypair_xonly_tweak_add(secp256k1_context_static, &keypair, tweak) != 0 else {
            preconditionFailure()
        }

        var tweakedSecretKey = [UInt8](repeating: 0, count: 32)
        guard secp256k1_keypair_sec(secp256k1_context_static, &tweakedSecretKey, &keypair) != 0 else {
            preconditionFailure()
        }
        // Result output
        return SecretKey(Data(tweakedSecretKey))!
    }

    public static let keyLength = 32
}
