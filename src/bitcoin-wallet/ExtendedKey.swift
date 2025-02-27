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

    fileprivate init(secretKey: SecretKey? = .none, pubkey: PubKey? = .none, chaincode: Data, fingerprint: Int, depth: Int, keyIndex: Int, mainnet: Bool) throws(Error) {
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
        try self.init(binaryData: data)
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
        Base58Encoder().encode(binaryData)
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
            hmac.update(data: pubkey.data)
        } else if let secretKey {
            // Hardened derivation
            hmac.update(data: Data([0x00]))
            hmac.update(data: secretKey.data)
        } else {
            preconditionFailure()
        }
        hmac.update(data: UInt32(keyIndex).bigEndian.binaryData)
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
    enum Error: Swift.Error, Equatable {
        case invalidEncoding, wrongDataLength, unknownNetwork, invalidPrivateKeyLength, invalidSecretKey, invalidPublicKeyEncoding, invalidPublicKey, zeroDepthNonZeroFingerprint, zeroDepthNonZeroIndex, invalidSeed, binaryDecodingError
    }
}

extension ExtendedKey: BinaryCodable {

    public init(from decoder: inout BinaryDecoder) throws(Error) {

        let version: UInt32
        do {
             version = try decoder.decode()
        } catch {
            throw .binaryDecodingError
        }

        guard version == mainHDKeyVersionPrivate || version == mainHDKeyVersionPublic || version == testHDKeyVersionPrivate || version == testHDKeyVersionPublic else {
            throw Error.unknownNetwork
        }
        let isMainnet = version == mainHDKeyVersionPrivate || version == mainHDKeyVersionPublic
        let isPrivate = version == mainHDKeyVersionPrivate || version == testHDKeyVersionPrivate

        let depth: Int
        let fingerprint: Int
        let keyIndex: Int
        let chaincode: Data
        do {
            depth = Int(try decoder.decode() as UInt8)
            fingerprint = Int(try decoder.decode() as UInt32)
            keyIndex = Int((try decoder.decode() as UInt32).byteSwapped)
            chaincode = try decoder.decode(32)
        } catch {
            throw .binaryDecodingError
        }

        var secretKey = SecretKey?.none
        var pubkey = PubKey?.none
        if isPrivate {
            guard let len = decoder.peek(), len == 0 else {
                throw Error.invalidPrivateKeyLength
            }
            do {
                try decoder.decode(1)
            } catch {
                throw .binaryDecodingError
            }

            let secretKeyData: Data
            do {
                secretKeyData = try decoder.decode(SecretKey.keyLength)
            } catch {
                throw .binaryDecodingError
            }
            guard let parsedSecretKey = SecretKey(secretKeyData) else {
                throw Error.invalidSecretKey
            }
            secretKey = parsedSecretKey
        } else {
            let pubkeyData: Data
            do {
                pubkeyData = try decoder.decode(PubKey.compressedLength)
            } catch {
                throw .binaryDecodingError
            }
            guard let parsedPubkey = PubKey(pubkeyData, skipCheck: true) else {
                throw Error.invalidPublicKeyEncoding
            }
            guard parsedPubkey.check() else {
                throw Error.invalidPublicKey
            }
            pubkey = parsedPubkey
        }
        try self.init(secretKey: secretKey, pubkey: pubkey, chaincode: chaincode, fingerprint: fingerprint, depth: depth, keyIndex: keyIndex, mainnet: isMainnet)
    }

    public func encode(to encoder: inout BinaryEncoder) {
        encodeVersion(to: &encoder)
        encoder.encode(UInt8(depth))
        encoder.encode(UInt32(fingerprint))
        encoder.encode(UInt32(keyIndex).bigEndian)
        encoder.encode(chaincode)
        if let secretKey {
            encoder.encode(Data([0]))
            encoder.encode(secretKey.data)
        } else if let pubkey {
            encoder.encode(pubkey.data)
        } else {
            fatalError()
        }
    }

    public func encodeVersion(to encoder: inout BinaryEncoder) {
        let version = if hasSecretKey {
            isMainnet ? mainHDKeyVersionPrivate : testHDKeyVersionPrivate
        } else {
            isMainnet ? mainHDKeyVersionPublic : testHDKeyVersionPublic
        }
        encoder.encode(version)
    }

    public func encodingSize(_ counter: inout BinaryEncodingSizeCounter) {
        counter.countSize(78)
    }

    public func encodingSizeVersion(_ counter: inout BinaryEncodingSizeCounter) {
        counter.count(UInt32.self)
    }

    var versionData: Data {
        var counter = BinaryEncodingSizeCounter()
        encodingSizeVersion(&counter)
        var encoder = BinaryEncoder(counter)
        encodeVersion(to: &encoder)
        return encoder.data
    }

    static let versionSize = MemoryLayout<UInt32>.size
}

private let mainHDKeyVersionPrivate = UInt32(0xe4ad8804) // LE: 0x0488ade4
private let mainHDKeyVersionPublic = UInt32(0x1eb28804) // LE: 0x0488b21e
private let testHDKeyVersionPrivate = UInt32(0x94833504) // LE: 0x04358394
private let testHDKeyVersionPublic = UInt32(0xcf873504) // LE: 0x043587cf
