import Foundation
import CSECP256K1

/// Elliptic curve SECP256K1 public key.
public struct PublicKey: Equatable, Hashable, Sendable, CustomStringConvertible {

    /// Derives a public key from a secret key.
    /// - Parameters:
    ///   - secretKey: The secret key.
    ///   - requireEvenY: Gets the internal (x-only) public key for the specified secret key.
    ///
    ///   Requires global signing context to be initialized.
    public init(_ secretKey: SecretKey, requireEvenY: Bool = false) {
        if requireEvenY {
            var keypair = CollectionOfOne(Keypair())
            var keypairSpan = keypair.mutableSpan
            guard eccSigningContext.keypairCreate(keypair: &keypairSpan, seckey: secretKey.data.span) != 0 else {
                preconditionFailure()
            }
            var xonlyPubkey = CollectionOfOne(XOnlyPubkey())
            var xonlyPubkeySpan = xonlyPubkey.mutableSpan
            var paritySpan = MutableSpan<Int32>?.none
            guard SECP256K1Context.shared.keypairXOnlyPub(pubkey: &xonlyPubkeySpan, pkParity: &paritySpan, keypair: keypair.span) != 0 else {
                preconditionFailure()
            }
            var xonlyPubkeyBytes = [UInt8](repeating: 0, count: PublicKey.xOnlyLength)
            var xonlyPubkeyBytesSpan = xonlyPubkeyBytes.mutableSpan
            guard SECP256K1Context.shared.xonlyPubkeySerialize(output32: &xonlyPubkeyBytesSpan, pubkey: xonlyPubkey.span) != 0 else {
                preconditionFailure()
            }
            data = Data([Self.pubkeySerializationTagEven] + xonlyPubkeyBytes)
            return
        }

        var pubkey = CollectionOfOne(Pubkey())
        var pubkeySpan = pubkey.mutableSpan
        guard eccSigningContext.ecPubkeyCreate(&pubkeySpan, secretKey: secretKey.data.span) != 0 else {
            preconditionFailure()
        }
        var pubkeyBytes = [UInt8](repeating: 0, count: Self.uncompressedLength)
        var length = CollectionOfOne(pubkeyBytes.count)
        var pubkeyBytesSpan = pubkeyBytes.mutableSpan
        var lengthSpan = length.mutableSpan

        guard SECP256K1Context.shared.ecPubkeySerialize(output: &pubkeyBytesSpan, outputlen: &lengthSpan, pubkey: pubkey.span, flags: UInt32(SECP256K1_EC_COMPRESSED)) != 0 else {
            preconditionFailure()
        }
        assert(length[0] == Self.compressedLength)
        data = Data(pubkeyBytes.prefix(length[0]))
    }

    public init?(_ hex: String, skipCheck: Bool = false) {
        guard let data = Data(hex: hex) else {
            return nil
        }
        self.init(data, skipCheck: skipCheck)
    }

    public init?(xOnly data: Data, hasEvenY: Bool = true) {
        guard data.count == PublicKey.xOnlyLength else {
            return nil
        }
        self.data = [hasEvenY ? Self.pubkeySerializationTagEven : Self.pubkeySerializationTagOdd] + data
    }

    /// BIP143: Checks that the public key is compressed.
    public init?<D: DataProtocol>(compressed data: D, skipCheck: Bool = false) {
        guard data.count == PublicKey.compressedLength &&
            (data.first! == Self.pubkeySerializationTagEven || data.first! == Self.pubkeySerializationTagOdd)
        else { return nil }
        self.data = Data(data)
        if !skipCheck && !check() { return nil }
    }

    /// Used mainly for Satoshi's hard-coded key (genesis block).
    /// Checks that the public key is uncompressed.
    public init?<D: DataProtocol>(uncompressed data: D, skipCheck: Bool = false) {
        guard
            data.count == PublicKey.uncompressedLength &&
            data.first! == Self.pubkeySerializationTagUncompressed
        else { return nil }
        self.data = Data(data)
        if !skipCheck && !check() { return nil }
    }

    /// Data will be checked to be either compressed or uncompressed public key encoding.
    public init?<D: DataProtocol>(_ data: D, skipCheck: Bool = false) {
        if data.count == PublicKey.uncompressedLength {
            self.init(uncompressed: data, skipCheck: skipCheck)
        } else {
            self.init(compressed: data, skipCheck: skipCheck)
        }
    }

    public let data: Data

    public var description: String {
        data.hex
    }

    /// Checks this public key's validity by parsing it and thus verifying that it represents a point on the elliptic curve.
    ///
    /// - Parameter useXOnly: Uses the x-only version of the internal parser.
    /// - Returns: Whether the key is valid after running the check.
    public func check(useXOnly: Bool = false) -> Bool {
        // Alternatively `pubkeyData.withContiguousStorageIfAvailable { … }` can be used.
        if useXOnly {
            var xonlyPubkey = CollectionOfOne(XOnlyPubkey())
            var xonlyPubkeySpan = xonlyPubkey.mutableSpan
            return SECP256K1Context.shared.xonlyPubkeyParse(pubkey: &xonlyPubkeySpan, input32: xOnlyData.span) != 0
        } else {
            var pubkey = CollectionOfOne(Pubkey())
            var pubkeySpan = pubkey.mutableSpan
            return SECP256K1Context.shared.ecPubkeyParse(&pubkeySpan, from: data.span) != 0
        }
    }

    /// If internal compressed data does not represent a point on the curve, this will return nil.
    public var uncompressedData: Data? {
        if data.count == Self.uncompressedLength { return data }
        return compressedToUncompressed(data)
    }

    /// If internal compressed data does not represent a point on the curve, this will return nil.
    public var compressedData: Data? {
        if data.count == Self.compressedLength { return data }
        return uncompressedToCompressed(data)
    }

    public var xOnlyData: Data { data.dropFirst() }

    private var xOnlyDataChecked: (x: Data, parity: Bool) {
        var pubkey = CollectionOfOne(Pubkey())
        var pubkeySpan = pubkey.mutableSpan
        guard SECP256K1Context.shared.ecPubkeyParse(&pubkeySpan, from: data.span) != 0 else {
            preconditionFailure()
        }

        var xonlyPubkey = CollectionOfOne(XOnlyPubkey())
        var xonlyPubkeySpan = xonlyPubkey.mutableSpan
        var parity = CollectionOfOne(Int32(-1))
        var paritySpan: MutableSpan<Int32>? = parity.mutableSpan
        guard SECP256K1Context.shared.xonlyPubkeyFromPubkey(xonlyPubkey: &xonlyPubkeySpan, pkParity: &paritySpan, pubkey: pubkey.span) != 0 else {
            preconditionFailure()
        }

        var xOnlyPubkeyBytes = [UInt8](repeating: 0, count: PublicKey.xOnlyLength)
        var xOnlyPubkeyBytesSpan = xOnlyPubkeyBytes.mutableSpan
        guard SECP256K1Context.shared.xonlyPubkeySerialize(output32: &xOnlyPubkeyBytesSpan, pubkey: xonlyPubkey.span) != 0 else {
            preconditionFailure()
        }

        return (
            x: Data(xOnlyPubkeyBytes),
            parity: parity[0] == 1
        )
    }

    public func matches(_ secretKey: SecretKey) -> Bool {
        self == PublicKey(secretKey)
    }

    public func verify(_ sig: ECDSASignature, for message: String) -> Bool {
        sig.verify(message: message, pubkey: self)
    }

    public func verify(_ sig: SchnorrSignature, for message: String) -> Bool {
        sig.verify(message: message, pubkey: self)
    }

    public func verify(_ sig: RecoverableSignature, for message: String) -> Bool {
        sig.verify(message: message, pubkey: self)
    }

    public var hasEvenY: Bool {
        if data.count == PublicKey.compressedLength {
            data.first! == Self.pubkeySerializationTagEven
        } else {
            data.last! & 1 == 0 // we look at the least significant bit of the y coordinate
        }
    }

    public var hasOddY: Bool {
        if data.count == PublicKey.compressedLength {
            data.first! == Self.pubkeySerializationTagOdd
        } else {
            data.last! & 1 == 1
        }
    }

    /// BIP32: Used to derive public keys.
    public func tweak(_ tweak: Data) -> PublicKey {
        var pubkey = CollectionOfOne(Pubkey())
        var pubkeySpan = pubkey.mutableSpan
        var result = SECP256K1Context.shared.ecPubkeyParse(&pubkeySpan, from: data.span)
        assert(result != 0)

        result = SECP256K1Context.shared.ecPubkeyTweakAdd(pubkey: &pubkeySpan, tweak32: tweak.span)
        assert(result != 0)

        var tweakedKey = [UInt8](repeating: 0, count: PublicKey.uncompressedLength)
        var outputLen = CollectionOfOne(tweakedKey.count)
        var tweakedKeySpan = tweakedKey.mutableSpan
        var outputLenSpan = outputLen.mutableSpan
        result = SECP256K1Context.shared.ecPubkeySerialize(output: &tweakedKeySpan, outputlen: &outputLenSpan, pubkey: pubkey.span, flags: UInt32(SECP256K1_EC_COMPRESSED))
        assert(result != 0)
        assert(outputLen[0] == PublicKey.compressedLength)
        return PublicKey(Data(tweakedKey.prefix(outputLen[0])))!
    }

    /// Internal key is an x-only public key.
    public func tweakXOnly(_ tweak: Data) -> PublicKey {
        // Base point (x)
        var xonlyPubkey = CollectionOfOne(XOnlyPubkey())
        var xonlyPubkeySpan = xonlyPubkey.mutableSpan
        guard SECP256K1Context.shared.xonlyPubkeyParse(pubkey: &xonlyPubkeySpan, input32: xOnlyData.span) != 0 else {
            preconditionFailure()
        }

        var pubkey = CollectionOfOne(Pubkey())
        var pubkeySpan = pubkey.mutableSpan
        guard SECP256K1Context.shared.xonlyPubkeyTweakAdd(outputPubkey: &pubkeySpan, internalPubkey: xonlyPubkey.span, tweak32: tweak.span) != 0 else {
            preconditionFailure()
        }

        var pubkeyBytes = [UInt8](repeating: 0, count: PublicKey.uncompressedLength)
        var outputLen = CollectionOfOne(pubkeyBytes.count)
        var pubkeyBytesSpan = pubkeyBytes.mutableSpan
        var outputLenSpan = outputLen.mutableSpan

        let result = SECP256K1Context.shared.ecPubkeySerialize(output: &pubkeyBytesSpan, outputlen: &outputLenSpan, pubkey: pubkey.span, flags: UInt32(SECP256K1_EC_COMPRESSED))
        assert(result != 0)
        assert(outputLen[0] == PublicKey.compressedLength)

        return PublicKey(Data(pubkeyBytes.prefix(outputLen[0])))!
    }

    package func checkTweak(_ tweakData: Data, outputKey: PublicKey) -> Bool {
        var xonlyPubkey = CollectionOfOne(XOnlyPubkey())
        var xonlyPubkeySpan = xonlyPubkey.mutableSpan
        guard SECP256K1Context.shared.xonlyPubkeyParse(pubkey: &xonlyPubkeySpan, input32: xOnlyData.span) != 0 else {
            preconditionFailure()
        }

        let parity = Int32(outputKey.hasOddY ? 1 : 0)
        return SECP256K1Context.shared.xonlyPubkeyTweakAddCheck(tweakedPubkey32: outputKey.xOnlyData.span, tweakedPkParity: parity, internalPubkey: xonlyPubkey.span, tweak32: tweakData.span) != 0
    }

    public static let uncompressedLength = 65
    public static let compressedLength = 33
    public static let xOnlyLength = 32

    public static let pubkeySerializationTagEven = UInt8(SECP256K1_TAG_PUBKEY_EVEN)
    public static let pubkeySerializationTagOdd = UInt8(SECP256K1_TAG_PUBKEY_ODD)
    public static let pubkeySerializationTagUncompressed = UInt8(SECP256K1_TAG_PUBKEY_UNCOMPRESSED)

    public static let satoshi = PublicKey(uncompressed: [0x04, 0x67, 0x8a, 0xfd, 0xb0, 0xfe, 0x55, 0x48, 0x27, 0x19, 0x67, 0xf1, 0xa6, 0x71, 0x30, 0xb7, 0x10, 0x5c, 0xd6, 0xa8, 0x28, 0xe0, 0x39, 0x09, 0xa6, 0x79, 0x62, 0xe0, 0xea, 0x1f, 0x61, 0xde, 0xb6, 0x49, 0xf6, 0xbc, 0x3f, 0x4c, 0xef, 0x38, 0xc4, 0xf3, 0x55, 0x04, 0xe5, 0x1e, 0xc1, 0x12, 0xde, 0x5c, 0x38, 0x4d, 0xf7, 0xba, 0x0b, 0x8d, 0x57, 0x8a, 0x4c, 0x70, 0x2b, 0x6b, 0xf1, 0x1d, 0x5f])!
}

private func compressedToUncompressed(_ pubkeyData: Data) -> Data? {
    var pubkey = CollectionOfOne(Pubkey())
    var pubkeySpan = pubkey.mutableSpan
    guard SECP256K1Context.shared.ecPubkeyParse(&pubkeySpan, from: pubkeyData.span) != 0 else {
        return nil
    }
    var uncompressedPubkeyBytes = [UInt8](repeating: 0, count: PublicKey.uncompressedLength)
    var length = CollectionOfOne(uncompressedPubkeyBytes.count)
    var uncompressedPubkeyBytesSpan = uncompressedPubkeyBytes.mutableSpan
    var lengthSpan = length.mutableSpan

    guard SECP256K1Context.shared.ecPubkeySerialize(output: &uncompressedPubkeyBytesSpan, outputlen: &lengthSpan, pubkey: pubkey.span, flags: UInt32(SECP256K1_EC_UNCOMPRESSED)) != 0 else {
        preconditionFailure()
    }
    assert(length[0] == PublicKey.uncompressedLength)
    return Data(uncompressedPubkeyBytes)
}

private func uncompressedToCompressed(_ pubkeyData: Data) -> Data? {
    var pubkey = CollectionOfOne(Pubkey())
    var pubkeySpan = pubkey.mutableSpan
    guard SECP256K1Context.shared.ecPubkeyParse(&pubkeySpan, from: pubkeyData.span) != 0 else {
        return nil
    }
    var compressedPubkeyBytes = [UInt8](repeating: 0, count: PublicKey.uncompressedLength)
    var length = CollectionOfOne(compressedPubkeyBytes.count)
    var compressedPubkeyBytesSpan = compressedPubkeyBytes.mutableSpan
    var lengthSpan = length.mutableSpan

    guard SECP256K1Context.shared.ecPubkeySerialize(output: &compressedPubkeyBytesSpan, outputlen: &lengthSpan, pubkey: pubkey.span, flags: UInt32(SECP256K1_EC_COMPRESSED)) != 0 else {
        preconditionFailure()
    }
    assert(length[0] == PublicKey.compressedLength)

    return Data(compressedPubkeyBytes.prefix(length[0]))
}
