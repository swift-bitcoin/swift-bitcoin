import Foundation
import BitcoinCrypto

enum HDExtendedKeyError: Error {
    case invalidEncoding, wrongDataLength, unknownNetwork, invalidPrivateKeyLength, invalidSecretKey, invalidPublicKeyEncoding, invalidPublicKey, zeroDepthNonZeroFingerprint, zeroDepthNonZeroIndex
}

/// A BIP32 extended key whether it be a private master key, extended private key or an extended public key.
struct HDExtendedKey {
    let network: WalletNetwork
    let secretKey: SecretKey?
    let publicKey: PublicKey?
    let chaincode: Data
    let fingerprint: Int
    let depth: Int
    let keyIndex: Int

    init(network: WalletNetwork = .main, secretKey: SecretKey? = .none, publicKey: PublicKey? = .none, chaincode: Data, fingerprint: Int, depth: Int, keyIndex: Int) throws {
        guard secretKey == .none && publicKey != .none || (secretKey != .none && publicKey == .none) else {
            preconditionFailure()
        }

        guard depth != 0 || fingerprint == 0 else {
            throw HDExtendedKeyError.zeroDepthNonZeroFingerprint
        }
        guard depth != 0 || keyIndex == 0 else {
            throw HDExtendedKeyError.zeroDepthNonZeroIndex
        }
        self.network = network
        self.secretKey = secretKey
        self.publicKey = publicKey
        self.chaincode = chaincode
        self.fingerprint = fingerprint
        self.depth = depth
        self.keyIndex = keyIndex
    }

    init(_ serialized: String) throws {
        guard let data = Base58.base58CheckDecode(serialized) else {
            throw HDExtendedKeyError.invalidEncoding
        }
        try self.init(data)
    }

    // TODO: Rename to `hasSecretKey`.
    var isPrivate: Bool {
        if secretKey != nil && publicKey == nil {
            true
        } else if secretKey == nil && publicKey != nil {
            false
        } else {
            fatalError()
        }
    }

    var serialized: String {
        Base58.base58CheckEncode(data)
    }
    
    /// Derives either a child private key from a parent private key, or a child public key form a parent public key.
    ///
    /// Part of  BIP32 implementation.
    ///
    /// - Parameters:
    ///   - child: The child index.
    ///   - harden: Whether to apply hardened derivation. Only applicable to private keys.
    /// - Returns: The derived child key.
    func derive(child: Int, harden: Bool = false) -> Self {
        let keyIndex = harden ? (1 << 31) + child : child
        let depth = depth + 1
        let publicKey = if let secretKey {
            PublicKey(secretKey)
        } else if let publicKey {
            publicKey
        } else {
            fatalError()
        }
        let publicKeyIdentifier = hash160(publicKey.data)
        let fingerprint = publicKeyIdentifier.withUnsafeBytes {
            $0.loadUnaligned(as: UInt32.self)
        }

        // assert(IsValid());
        // assert(IsCompressed());
        let hmacResult: Data
        if keyIndex >> 31 == 0 {
            // Unhardened derivation
            var publicKeyData = publicKey.data
            publicKeyData.appendBytes(UInt32(keyIndex).bigEndian)
            hmacResult = hmacSHA512(chaincode, data: publicKeyData)
        } else if let secretKey {
            // Hardened derivation
            var privateKeyData = Data([0x00])
            privateKeyData.append(secretKey.data)
            privateKeyData.appendBytes(UInt32(keyIndex).bigEndian)
            hmacResult = hmacSHA512(chaincode, data: privateKeyData)
        } else {
            fatalError()
        }

        let chaincode = hmacResult[hmacResult.startIndex.advanced(by: 32)...]

        let tweak = hmacResult[..<hmacResult.startIndex.advanced(by: 32)]
        let newSecretKey: SecretKey? = if let secretKey {
            secretKey.tweak(tweak)
        } else { .none }

        let newPublicKey: PublicKey? = if let publicKey = self.publicKey {
            publicKey.tweak(tweak)
        } else { .none }

        guard let ret = try? Self(secretKey: newSecretKey, publicKey: newPublicKey, chaincode: chaincode, fingerprint: Int(fingerprint), depth: depth, keyIndex: keyIndex) else {
            preconditionFailure()
        }
        return ret
    }

    /// Turns a private key into a public key removing its ability to produce signatures.
    var neutered: Self {
        guard let secretKey else { preconditionFailure() }
        let publicKey = PublicKey(secretKey)
        guard let ret = try? Self(secretKey: .none, publicKey: publicKey, chaincode: chaincode, fingerprint: fingerprint, depth: depth, keyIndex: keyIndex) else {
            preconditionFailure()
        }
        return ret
    }
}

extension HDExtendedKey {

    init(_ data: Data) throws {
        guard data.count == Self.size else {
            throw HDExtendedKeyError.wrongDataLength
        }

        var data = data
        let version = data.withUnsafeBytes {
            $0.loadUnaligned(as: UInt32.self)
        }.byteSwapped // Convert to little-endian

        guard let network = WalletNetwork.fromHDKeyVersion(version) else {
            throw HDExtendedKeyError.unknownNetwork
        }

        data = data.dropFirst(MemoryLayout<UInt32>.size)

        let depth = data.withUnsafeBytes {
            $0.loadUnaligned(as: UInt8.self)
        }
        data = data.dropFirst(MemoryLayout<UInt8>.size)

        let fingerprint = data.withUnsafeBytes {
            $0.loadUnaligned(as: UInt32.self)
        }
        data = data.dropFirst(MemoryLayout<UInt32>.size)

        let keyIndex = data.withUnsafeBytes {
            $0.loadUnaligned(as: UInt32.self)
        }.byteSwapped // Convert to little-endian
        data = data.dropFirst(MemoryLayout<UInt32>.size)

        let chaincode = data[..<data.startIndex.advanced(by: 32)]
        data = data.dropFirst(32)

        var secretKey = SecretKey?.none
        var publicKey = PublicKey?.none
        let isPrivate = version == network.hdKeyVersionPrivate
        if isPrivate {
            guard data[data.startIndex] == 0 else {
                throw HDExtendedKeyError.invalidPrivateKeyLength
            }
            let secretKeyData = data[data.startIndex.advanced(by: 1)..<data.startIndex.advanced(by: PublicKey.compressedLength)]
            guard let parsedSecretKey = SecretKey(secretKeyData) else {
                throw HDExtendedKeyError.invalidSecretKey
            }
            secretKey = parsedSecretKey
        } else {
            let publicKeyData = data[..<data.startIndex.advanced(by: PublicKey.compressedLength)]
            guard let parsedPublicKey = PublicKey(publicKeyData) else {
                throw HDExtendedKeyError.invalidPublicKeyEncoding
            }
            guard parsedPublicKey.isPointOnCurve() else {
                throw HDExtendedKeyError.invalidPublicKey
            }
            publicKey = parsedPublicKey
        }
        data = data.dropFirst(PublicKey.compressedLength)
        try self.init(network: network, secretKey: secretKey, publicKey: publicKey, chaincode: chaincode, fingerprint: Int(fingerprint), depth: Int(depth), keyIndex: Int(keyIndex))
    }

    var versionData: Data {
        var ret = Data(count: Self.versionSize)
        let version = if isPrivate {
            network.hdKeyVersionPrivate
        } else {
            network.hdKeyVersionPublic
        }
        ret.addBytes(UInt32(version).bigEndian)
        return ret
    }

    var data: Data {
        var ret = Data(count: Self.size)
        var offset = ret.addData(versionData)
        offset = ret.addBytes(UInt8(depth), at: offset)
        offset = ret.addBytes(UInt32(fingerprint), at: offset)
        offset = ret.addBytes(UInt32(keyIndex).bigEndian, at: offset)
        offset = ret.addData(chaincode, at: offset)
        if let secretKey {
            offset = ret.addData([0], at: offset)
            ret.addData(secretKey.data, at: offset)
        } else if let publicKey {
            ret.addData(publicKey.data, at: offset)
        } else {
            fatalError()
        }
        return ret
    }

    static let versionSize = MemoryLayout<UInt32>.size
    static let size = 78
}
