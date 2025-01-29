import Foundation
import BitcoinCrypto

/// A BIP32 extended key whether it be a private master key, extended private key or an extended public key.
public struct ExtendedKey {
    public let isMainnet: Bool
    public let secretKey: SecretKey?
    public let pubkey: PubKey?
    public let chaincode: Data
    public let fingerprint: Int
    public let depth: Int
    public let keyIndex: Int

    public init(seed: Data, mainnet: Bool = true) throws {
        guard seed.count >= 16, seed.count <= 64 else {
            throw Error.invalidSeed
        }
        var hmac = HMAC<SHA512>(key: .init(data: "Bitcoin seed".data(using: .ascii)!))
        hmac.update(data: seed)
        let result = Data(hmac.finalize())
        let secretKeyData = result.prefix(32)
        let chaincode = result.dropFirst(32)
        guard let secretKey = SecretKey(secretKeyData) else {
            throw Error.invalidSeed
        }
        try self.init(secretKey: secretKey, chaincode: chaincode, fingerprint: 0, depth: 0, keyIndex: 0, mainnet: mainnet)
    }

    private init(secretKey: SecretKey? = .none, pubkey: PubKey? = .none, chaincode: Data, fingerprint: Int, depth: Int, keyIndex: Int, mainnet: Bool) throws {
        guard secretKey == .none && pubkey != .none || (secretKey != .none && pubkey == .none) else {
            preconditionFailure()
        }

        guard depth != 0 || fingerprint == 0 else {
            throw Error.zeroDepthNonZeroFingerprint
        }
        guard depth != 0 || keyIndex == 0 else {
            throw Error.zeroDepthNonZeroIndex
        }
        self.isMainnet = mainnet
        self.secretKey = secretKey
        self.pubkey = pubkey
        self.chaincode = chaincode
        self.fingerprint = fingerprint
        self.depth = depth
        self.keyIndex = keyIndex
    }

    public init(_ serialized: String) throws {
        guard let data = Base58Decoder().decode(serialized) else {
            throw Error.invalidEncoding
        }
        try self.init(data)
    }

    public var hasSecretKey: Bool {
        if secretKey != nil && pubkey == nil {
            true
        } else if secretKey == nil && pubkey != nil {
            false
        } else {
            fatalError()
        }
    }

    public var serialized: String {
        Base58Encoder().encode(data)
    }
    
    /// Derives either a child private key from a parent private key, or a child public key form a parent public key.
    ///
    /// Part of  BIP32 implementation.
    ///
    /// - Parameters:
    ///   - child: The child index.
    ///   - harden: Whether to apply hardened derivation. Only applicable to private keys.
    /// - Returns: The derived child key.
    public func derive(child: Int, harden: Bool = false) -> Self {
        precondition(!harden || hasSecretKey)

        let keyIndex = harden ? (1 << 31) + child : child
        let depth = depth + 1
        let pubkey = if let secretKey {
            PubKey(secretKey)
        } else if let pubkey {
            pubkey
        } else {
            fatalError()
        }
        let pubkeyID = Data(Hash160.hash(data: pubkey.data))
        let fingerprint = pubkeyID.withUnsafeBytes {
            $0.loadUnaligned(as: UInt32.self)
        }

        // assert(IsValid());
        // assert(IsCompressed());
        var hmac = HMAC<SHA512>(key: .init(data: chaincode))
        if keyIndex >> 31 == 0 {
            // Unhardened derivation
            var pubkeyData = pubkey.data
            pubkeyData.appendBytes(UInt32(keyIndex).bigEndian)
            hmac.update(data: pubkeyData)
        } else if let secretKey {
            // Hardened derivation
            var privateKeyData = Data([0x00])
            privateKeyData.append(secretKey.data)
            privateKeyData.appendBytes(UInt32(keyIndex).bigEndian)
            hmac.update(data: privateKeyData)
        } else {
            preconditionFailure()
        }
        let hmacResult = Data(hmac.finalize())
        let chaincode = hmacResult.dropFirst(32)
        let tweak = hmacResult.prefix(32)
        let newSecretKey: SecretKey? = if let secretKey {
            secretKey.tweak(tweak)
        } else { .none }

        let newPubkey: PubKey? = if let pubkey = self.pubkey {
            pubkey.tweak(tweak)
        } else { .none }

        guard let ret = try? Self(secretKey: newSecretKey, pubkey: newPubkey, chaincode: chaincode, fingerprint: Int(fingerprint), depth: depth, keyIndex: keyIndex, mainnet: isMainnet) else {
            preconditionFailure()
        }
        return ret
    }

    /// Turns a private key into a public key removing its ability to produce signatures.
    public var neutered: Self {
        guard let secretKey else { preconditionFailure() }
        let pubkey = PubKey(secretKey)
        guard let ret = try? Self(secretKey: .none, pubkey: pubkey, chaincode: chaincode, fingerprint: fingerprint, depth: depth, keyIndex: keyIndex, mainnet: isMainnet) else {
            preconditionFailure()
        }
        return ret
    }
}

/// Error
public extension ExtendedKey {
    enum Error: Swift.Error {
        case invalidEncoding, wrongDataLength, unknownNetwork, invalidPrivateKeyLength, invalidSecretKey, invalidPublicKeyEncoding, invalidPublicKey, zeroDepthNonZeroFingerprint, zeroDepthNonZeroIndex, invalidSeed
    }
}

public extension ExtendedKey {

    init(_ data: Data) throws {
        guard data.count == Self.size else {
            throw Error.wrongDataLength
        }

        var data = data
        let version = data.withUnsafeBytes {
            $0.loadUnaligned(as: UInt32.self)
        }.byteSwapped // Convert to little-endian

        guard version == mainHDKeyVersionPrivate || version == mainHDKeyVersionPublic || version == testHDKeyVersionPrivate || version == testHDKeyVersionPublic else {
            throw Error.unknownNetwork
        }
        let mainnet = version == mainHDKeyVersionPrivate || version == mainHDKeyVersionPublic
        let isPrivate = version == mainHDKeyVersionPrivate || version == testHDKeyVersionPrivate

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

        let chaincode = data.prefix(32)
        data = data.dropFirst(32)

        var secretKey = SecretKey?.none
        var pubkey = PubKey?.none
        if isPrivate {
            guard let len = data.first, len == 0 else {
                throw Error.invalidPrivateKeyLength
            }
            let secretKeyData = data.dropFirst().prefix(SecretKey.keyLength)
            guard let parsedSecretKey = SecretKey(secretKeyData) else {
                throw Error.invalidSecretKey
            }
            secretKey = parsedSecretKey
        } else {
            let pubkeyData = data.prefix(PubKey.compressedLength)
            guard let parsedPubkey = PubKey(pubkeyData, skipCheck: true) else {
                throw Error.invalidPublicKeyEncoding
            }
            guard parsedPubkey.check() else {
                throw Error.invalidPublicKey
            }
            pubkey = parsedPubkey
        }
        data = data.dropFirst(PubKey.compressedLength)
        try self.init(secretKey: secretKey, pubkey: pubkey, chaincode: chaincode, fingerprint: Int(fingerprint), depth: Int(depth), keyIndex: Int(keyIndex), mainnet: mainnet)
    }

    var versionData: Data {
        var ret = Data(count: Self.versionSize)
        let version = if hasSecretKey {
            isMainnet ? mainHDKeyVersionPrivate : testHDKeyVersionPrivate
        } else {
            isMainnet ? mainHDKeyVersionPublic : testHDKeyVersionPublic
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
        } else if let pubkey {
            ret.addData(pubkey.data, at: offset)
        } else {
            fatalError()
        }
        return ret
    }

    static let versionSize = MemoryLayout<UInt32>.size
    static let size = 78
}

private let mainHDKeyVersionPrivate = 0x0488ade4
private let mainHDKeyVersionPublic = 0x0488b21e
private let testHDKeyVersionPrivate = 0x04358394
private let testHDKeyVersionPublic = 0x043587cf


// TODO: Remove this extension and use BinaryEncoder / Decoder (or conform to BinaryCodable instead)
extension Data {

    mutating func appendBytes<T>(_ value: T) {
        Swift.withUnsafeBytes(of: value) {
            append(contentsOf: $0)
        }
    }

    @discardableResult
    mutating func addBytes<T>(_ value: T, at offset: Self.Index? = .none) -> Self.Index {
        let offset = offset ?? startIndex
        let count = MemoryLayout.size(ofValue: value)
        precondition(self[offset...].count >= count)
        Swift.withUnsafePointer(to: value) { replaceSubrange(offset ..< offset.advanced(by: count), with: $0, count: count) }
        return offset.advanced(by: count)
    }

    @discardableResult
    mutating func addData<T: DataProtocol>(_ value: T, at offset: Self.Index? = .none) -> Self.Index {
        let offset = offset ?? startIndex
        let count = value.count
        precondition(self[offset...].count >= count)
        replaceSubrange(offset ..< offset.advanced(by: count), with: value)
        return offset.advanced(by: count)
    }
}
