import Foundation
import LibSECP256k1

/// Elliptic curve SECP256K1 public key.
public struct PublicKey: Equatable, Sendable, CustomStringConvertible {
    
    /// Derives a public key from a secret key.
    /// - Parameters:
    ///   - secretKey: The secret key.
    ///   - requireEvenY: Gets the internal (x-only) public key for the specified secret key.
    ///
    ///   Requires global signing context to be initialized.
    public init(_ secretKey: SecretKey, requireEvenY: Bool = false) {
        let secretKeyBytes = [UInt8](secretKey.data)

        if requireEvenY {
            var keypair = secp256k1_keypair()
            guard secp256k1_keypair_create(eccSigningContext, &keypair, secretKeyBytes) != 0 else {
                preconditionFailure()
            }
            var xonlyPubkey = secp256k1_xonly_pubkey()
            guard secp256k1_keypair_xonly_pub(secp256k1_context_static, &xonlyPubkey, nil, &keypair) != 0 else {
                preconditionFailure()
            }
            var xonlyPubkeyBytes = [UInt8](repeating: 0, count: PublicKey.xOnlyLength)
            guard secp256k1_xonly_pubkey_serialize(secp256k1_context_static, &xonlyPubkeyBytes, &xonlyPubkey) != 0 else {
                preconditionFailure()
            }
            data = Data([Self.publicKeySerializationTagEven] + xonlyPubkeyBytes)
            return
        }

        var pubkey = secp256k1_pubkey()
        guard secp256k1_ec_pubkey_create(eccSigningContext, &pubkey, secretKeyBytes) != 0 else {
            preconditionFailure()
        }
        var publicKeyBytes = [UInt8](repeating: 0, count: Self.compressedLength)
        var publicKeyBytesCount = publicKeyBytes.count
        guard secp256k1_ec_pubkey_serialize(secp256k1_context_static, &publicKeyBytes, &publicKeyBytesCount, &pubkey, UInt32(SECP256K1_EC_COMPRESSED)) != 0 else {
            preconditionFailure()
        }
        assert(publicKeyBytesCount == Self.compressedLength)
        data = Data(publicKeyBytes)
    }

    public init?(_ hex: String) {
        guard let data = Data(hex: hex) else {
            return nil
        }
        self.init(data)
    }

    public init?(xOnly data: Data, hasEvenY: Bool = true) {
        guard data.count == PublicKey.xOnlyLength else {
            return nil
        }
        // precondition(checkXOnly(data)) // TODO: Just remove if this fails sometimes during taproot witness verification.
        self.data = [hasEvenY ? Self.publicKeySerializationTagEven : Self.publicKeySerializationTagOdd] + data
    }

    /// BIP143: Checks that the public key is  compressed.
    public init?<D: DataProtocol>(compressed data: D) {
        guard data.count == PublicKey.compressedLength &&
            (data.first! == Self.publicKeySerializationTagEven || data.first! == Self.publicKeySerializationTagOdd) else {
            return nil
        }
        self.data = Data(data)
    }

    /// Used mainly for Satoshi's hard-coded key (genesis block).
    /// BIP143: Checks that the public key is  uncompressed.
    public init?<D: DataProtocol>(uncompressed data: D) {
        guard
            data.count == PublicKey.uncompressedLength &&
            data.first! == Self.publicKeySerializationTagUncompressed,
            let compressedData = uncompressedToCompressed(Data(data))
        else { return nil }
        self.data = compressedData
    }

    /// Data will be checked to be either compressed or uncompressed public key encoding.
    public init?(_ data: Data) {
        guard (
            data.count == PublicKey.compressedLength &&
            (data.first! == Self.publicKeySerializationTagEven || data.first! == Self.publicKeySerializationTagOdd)
        ) || (
            data.count == PublicKey.uncompressedLength &&
            data.first! == Self.publicKeySerializationTagUncompressed
        ) else {
            return nil
        }
        if data.count == PublicKey.uncompressedLength {
            guard let compressedData = uncompressedToCompressed(data) else {
                return nil
            }
            self.data = compressedData
        } else {
            self.data = data
        }
    }

    public let data: Data

    public var description: String {
        data.hex
    }

    public func isPointOnCurve(useXOnly: Bool = false) -> Bool {
        if useXOnly {
            checkXOnly(xOnlyData)
        } else {
            checkPublicKey(data)
        }
    }

    /// If internal compressed data does not represent a point on the curve, this will return nil.
    public var uncompressedData: Data? {
        compressedToUncompressed(data)
    }

    public var xOnlyData: Data { data.dropFirst() }

    private var xOnlyDataChecked: (x: Data, parity: Bool) {
        let publicKeyBytes = [UInt8](data)

        var pubkey = secp256k1_pubkey()
        guard secp256k1_ec_pubkey_parse(secp256k1_context_static, &pubkey, publicKeyBytes, publicKeyBytes.count) != 0 else {
            preconditionFailure()
        }

        var parity: Int32 = -1
        var xonlyPubkey = secp256k1_xonly_pubkey()
        guard secp256k1_xonly_pubkey_from_pubkey(secp256k1_context_static, &xonlyPubkey, &parity, &pubkey) != 0 else {
            preconditionFailure()
        }

        var xOnlyPubkeyBytes = [UInt8](repeating: 0, count: PublicKey.xOnlyLength)
        guard secp256k1_xonly_pubkey_serialize(secp256k1_context_static, &xOnlyPubkeyBytes, &xonlyPubkey) != 0 else {
            preconditionFailure()
        }

        return (
            x: Data(xOnlyPubkeyBytes),
            parity: parity == 1
        )
    }

    public func matches(_ secretKey: SecretKey) -> Bool {
        self == PublicKey(secretKey)
    }

    public func verify(_ signature: Signature, for message: String) -> Bool {
        signature.verify(message: message, publicKey: self)
    }

    public var hasEvenY: Bool {
        data.first! == Self.publicKeySerializationTagEven
    }

    public var hasOddY: Bool {
        data.first! == Self.publicKeySerializationTagOdd
    }

    /// BIP32: Used to derive public keys.
    public func tweak(_ tweak: Data) -> PublicKey {
        var publicKeyBytes = [UInt8](data)
        var tweak = [UInt8](tweak)

        var pubkey: secp256k1_pubkey = .init()
        var result = secp256k1_ec_pubkey_parse(secp256k1_context_static, &pubkey, &publicKeyBytes, publicKeyBytes.count)
        assert(result != 0)

        result = secp256k1_ec_pubkey_tweak_add(secp256k1_context_static, &pubkey, &tweak)
        assert(result != 0)

        let tweakedKey: [UInt8] = .init(unsafeUninitializedCapacity: PublicKey.compressedLength) { buf, len in
            len = Self.compressedLength
            result = secp256k1_ec_pubkey_serialize(secp256k1_context_static, buf.baseAddress!, &len, &pubkey, UInt32(SECP256K1_EC_COMPRESSED))
            assert(result != 0)
            assert(len == PublicKey.compressedLength)
        }
        return PublicKey(Data(tweakedKey))!
    }

    /// Internal key is an x-only public key.
    public func tweakXOnly(_ tweak: Data) -> PublicKey {
        let xOnlyPublicKeyBytes = [UInt8](xOnlyData)
        let tweakBytes = [UInt8](tweak)

        // Base point (x)
        var xonlyPubkey = secp256k1_xonly_pubkey()
        guard secp256k1_xonly_pubkey_parse(secp256k1_context_static, &xonlyPubkey, xOnlyPublicKeyBytes) != 0 else {
            preconditionFailure()
        }

        var pubkey = secp256k1_pubkey()
        guard secp256k1_xonly_pubkey_tweak_add(secp256k1_context_static, &pubkey, &xonlyPubkey, tweakBytes) != 0 else {
            preconditionFailure()
        }

        let publicKeyBytes: [UInt8] = .init(unsafeUninitializedCapacity: PublicKey.compressedLength) { buf, len in
            len = Self.compressedLength
            let result = secp256k1_ec_pubkey_serialize(secp256k1_context_static, buf.baseAddress!, &len, &pubkey, UInt32(SECP256K1_EC_COMPRESSED))
            assert(result != 0)
            assert(len == PublicKey.compressedLength)

        }
        return PublicKey(Data(publicKeyBytes))!
    }

    package func checkTweak(_ tweakData: Data, outputKey: PublicKey) -> Bool {
        let internalKeyBytes = [UInt8](xOnlyData)
        let outputKeyBytes = [UInt8](outputKey.xOnlyData)
        let tweakBytes = [UInt8](tweakData)

        var xonlyPubkey = secp256k1_xonly_pubkey()
        guard secp256k1_xonly_pubkey_parse(secp256k1_context_static, &xonlyPubkey, internalKeyBytes) != 0 else {
            preconditionFailure()
        }

        let parity = Int32(outputKey.hasOddY ? 1 : 0)
        return secp256k1_xonly_pubkey_tweak_add_check(secp256k1_context_static, outputKeyBytes, parity, &xonlyPubkey, tweakBytes) != 0
    }

    public static let uncompressedLength = 65
    public static let compressedLength = 33
    public static let xOnlyLength = 32

    public static let publicKeySerializationTagEven = UInt8(SECP256K1_TAG_PUBKEY_EVEN)
    public static let publicKeySerializationTagOdd = UInt8(SECP256K1_TAG_PUBKEY_ODD)
    public static let publicKeySerializationTagUncompressed = UInt8(SECP256K1_TAG_PUBKEY_UNCOMPRESSED)

    public static let satoshi = PublicKey(uncompressed: [0x04, 0x67, 0x8a, 0xfd, 0xb0, 0xfe, 0x55, 0x48, 0x27, 0x19, 0x67, 0xf1, 0xa6, 0x71, 0x30, 0xb7, 0x10, 0x5c, 0xd6, 0xa8, 0x28, 0xe0, 0x39, 0x09, 0xa6, 0x79, 0x62, 0xe0, 0xea, 0x1f, 0x61, 0xde, 0xb6, 0x49, 0xf6, 0xbc, 0x3f, 0x4c, 0xef, 0x38, 0xc4, 0xf3, 0x55, 0x04, 0xe5, 0x1e, 0xc1, 0x12, 0xde, 0x5c, 0x38, 0x4d, 0xf7, 0xba, 0x0b, 0x8d, 0x57, 0x8a, 0x4c, 0x70, 0x2b, 0x6b, 0xf1, 0x1d, 0x5f])!
}

private func compressedToUncompressed(_ publicKeyData: Data) -> Data? {
    let publicKeyBytes = [UInt8](publicKeyData)
    var pubkey = secp256k1_pubkey()
    guard secp256k1_ec_pubkey_parse(secp256k1_context_static, &pubkey, publicKeyBytes, publicKeyBytes.count) != 0 else {
        return .none
    }
    var uncompressedPublicKeyBytes = [UInt8](repeating: 0, count: PublicKey.uncompressedLength)
    var uncompressedPublicKeyBytesCount = uncompressedPublicKeyBytes.count
    guard secp256k1_ec_pubkey_serialize(secp256k1_context_static, &uncompressedPublicKeyBytes, &uncompressedPublicKeyBytesCount, &pubkey, UInt32(SECP256K1_EC_UNCOMPRESSED)) != 0 else {
        preconditionFailure()
    }
    assert(uncompressedPublicKeyBytesCount == PublicKey.uncompressedLength)
    return Data(uncompressedPublicKeyBytes)
}

private func uncompressedToCompressed(_ publicKeyData: Data) -> Data? {
    let publicKeyBytes = [UInt8](publicKeyData)

    var pubkey = secp256k1_pubkey()
    guard secp256k1_ec_pubkey_parse(secp256k1_context_static, &pubkey, publicKeyBytes, publicKeyBytes.count) != 0 else {
        return .none
    }
    var compressedPublicKeyBytes = [UInt8](repeating: 0, count: PublicKey.compressedLength)
    var compressedPublicKeyBytesCount = compressedPublicKeyBytes.count
    guard secp256k1_ec_pubkey_serialize(secp256k1_context_static, &compressedPublicKeyBytes, &compressedPublicKeyBytesCount, &pubkey, UInt32(SECP256K1_EC_COMPRESSED)) != 0 else {
        preconditionFailure()
    }
    assert(compressedPublicKeyBytesCount == PublicKey.compressedLength)

    return Data(compressedPublicKeyBytes)
}

/// Checks that a public key is valid.
private func checkPublicKey(_ publicKeyData: Data) -> Bool {
    // Alternatively `publicKeyData.withContiguousStorageIfAvailable { … }` can be used.
    let publicKeyBytes = [UInt8](publicKeyData)
    var pubkey = secp256k1_pubkey()
    return secp256k1_ec_pubkey_parse(secp256k1_context_static, &pubkey, publicKeyBytes, publicKeyBytes.count) != 0
}

private func checkXOnly(_ publicKeyData: Data) -> Bool {
    let publicKeyBytes = [UInt8](publicKeyData)
    var xonlyPubkey = secp256k1_xonly_pubkey()
    return  secp256k1_xonly_pubkey_parse(secp256k1_context_static, &xonlyPubkey, publicKeyBytes) != 0
}
