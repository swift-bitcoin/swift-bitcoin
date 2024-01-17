import Foundation
import CryptoUtils

/// A BIP32 extended key whether it be a private master key, extended private key or an extended public key.
struct HDExtendedKey {
    let network: WalletNetwork
    let isPrivate: Bool
    let key: Data
    let chaincode: Data
    let fingerprint: Int
    let depth: Int
    let keyIndex: Int

    init(network: WalletNetwork = .main, isPrivate: Bool, key: Data, chaincode: Data, fingerprint: Int, depth: Int, keyIndex: Int) {
        self.network = network
        self.isPrivate = isPrivate
        self.key = key
        self.chaincode = chaincode
        self.fingerprint = fingerprint
        self.depth = depth
        self.keyIndex = keyIndex
    }

    init?(_ serialized: String) {
        guard let data = Base58.base58CheckDecode(serialized) else {
            return nil
        }
        self.init(data)
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
        let publicKey = isPrivate ? getPublicKey(secretKey: key) : key
        let publicKeyIdentifier = hash160(publicKey)
        let fingerprint = publicKeyIdentifier.withUnsafeBytes {
            $0.loadUnaligned(as: UInt32.self)
        }

        // assert(IsValid());
        // assert(IsCompressed());
        let hmacResult: Data
        if keyIndex >> 31 == 0 {
            // Unhardened derivation
            var publicKeyData = isPrivate ? publicKey : key
            publicKeyData.appendBytes(UInt32(keyIndex).bigEndian)
            hmacResult = hmacSHA512(chaincode, data: publicKeyData)
        } else {
            // Hardened derivation
            precondition(isPrivate)
            var privateKeyData = Data([0x00])
            privateKeyData.append(key)
            privateKeyData.appendBytes(UInt32(keyIndex).bigEndian)
            hmacResult = hmacSHA512(chaincode, data: privateKeyData)
        }

        let chaincode = hmacResult[hmacResult.startIndex.advanced(by: 32)...]

        let tweak = hmacResult[..<hmacResult.startIndex.advanced(by: 32)]
        let key = if isPrivate {
            tweakSecretKey(key, tweak: tweak)
        } else {
            tweakPublicKey(key, tweak: tweak)
        }

        return .init(isPrivate: isPrivate, key: key, chaincode: chaincode, fingerprint: Int(fingerprint), depth: depth, keyIndex: keyIndex)
    }

    /// Turns a private key into a public key removing its ability to produce signatures.
    var neutered: Self {
        let publicKey = getPublicKey(secretKey: key)
        return .init(isPrivate: false, key: publicKey, chaincode: chaincode, fingerprint: fingerprint, depth: depth, keyIndex: keyIndex)
    }
}

extension HDExtendedKey {

    init?(_ data: Data) {
        guard data.count == Self.size else { return nil }

        var remainingData = data
        let version = remainingData.withUnsafeBytes {
            $0.loadUnaligned(as: UInt32.self)
        }.byteSwapped // Convert to little-endian

        guard let network = WalletNetwork.fromHDKeyVersion(version) else {
            return nil
        }

        remainingData = remainingData.dropFirst(MemoryLayout<UInt32>.size)

        let depth = remainingData.withUnsafeBytes {
            $0.loadUnaligned(as: UInt8.self)
        }
        remainingData = remainingData.dropFirst(MemoryLayout<UInt8>.size)

        let fingerprint = remainingData.withUnsafeBytes {
            $0.loadUnaligned(as: UInt32.self)
        }
        remainingData = remainingData.dropFirst(MemoryLayout<UInt32>.size)

        let keyIndex = remainingData.withUnsafeBytes {
            $0.loadUnaligned(as: UInt32.self)
        }.byteSwapped // Convert to little-endian
        remainingData = remainingData.dropFirst(MemoryLayout<UInt32>.size)

        let chaincode = remainingData[..<remainingData.startIndex.advanced(by: 32)]
        remainingData = remainingData.dropFirst(32)

        let isPrivate = version == network.hdKeyVersionPrivate

        let key = if isPrivate {
            remainingData[remainingData.startIndex.advanced(by: 1)..<remainingData.startIndex.advanced(by: 33)]
        } else {
            remainingData[..<remainingData.startIndex.advanced(by: 33)]
        }
        remainingData = remainingData.dropFirst(33)
        self.init(network: network, isPrivate: isPrivate, key: key, chaincode: chaincode, fingerprint: Int(fingerprint), depth: Int(depth), keyIndex: Int(keyIndex))
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
        if isPrivate {
            offset = ret.addData([0], at: offset)
        }
        ret.addData(key, at: offset)
        return ret
    }

    static let versionSize = MemoryLayout<UInt32>.size
    static let size = 78
}
