import Foundation

#if canImport(CryptoKit)
import CryptoKit
#elseif canImport(Crypto)
import Crypto
#endif

fileprivate let bitsPerByte = UInt8.bitWidth
fileprivate let bitsPerMnemonicWord = 11
fileprivate let mnemonicEntropyMin = 16 // Bytes
fileprivate let mnemonicEntropyMax = 32 // Bytes
fileprivate let mnemonicEntropyMultiple = 4 // Bytes

/// Namespase for common wallet operations. From seed to derivation paths.
public enum Wallet {

    /// Creates a random seed (entropy) for HD wallets.
    /// - Parameter bytes: The length of the seed to generate.
    /// - Returns: The generated seed serialized as hexadecimal.
    public static func generateSeed(bytes: Int = 32) -> String {
        getRandBytes(bytes).hex
    }

    /// Creates the extended master private key for a hierarchical deterministic wallet using the provided seed.
    /// - Parameter seedHex: The seed in hex format.
    /// - Returns: The serialized extended master private key.
    public static func computeHDMasterKey(_ seedHex: String) throws -> String {
        guard let seed = Data(hex: seedHex) else {
            throw WalletError.invalidHexString
        }
        precondition(seed.count >= 16 && seed.count <= 64)
        let result = hmacSHA512("Bitcoin seed", data: seed)
        let key = result[...result.startIndex.advanced(by: 31)]
        let chaincode = result[result.startIndex.advanced(by: 32)...]
        let hdKey = HDExtendedKey(isPrivate: true, key: key, chaincode: chaincode, fingerprint: 0, depth: 0, keyIndex: 0)
        return hdKey.serialized
    }

    /// Derives a new private/public key from a parent extended private/public key.
    /// - Parameters:
    ///   - isPrivate: Whether the provided key should be interpreted as a private or a public key. This is checked against the value obtained from deserializing the provided key.
    ///   - keyHex: The parent extended private/public key.
    ///   - index: The child index to derive.
    ///   - harden: Whether to apply hardened derivation (only for private keys).
    /// - Returns: The newly derived child extended private/public key.
    public static func deriveHDKey(isPrivate: Bool = true, key keyHex: String, index: Int, harden: Bool = false) throws -> String {
        guard let hdKey = HDExtendedKey(keyHex) else {
            throw WalletError.invalidExtendedKey
        }
        if isPrivate && !hdKey.isPrivate || (!isPrivate && hdKey.isPrivate) {
            throw WalletError.invalidExtendedKeyType
        }
        if !isPrivate && harden {
            throw WalletError.attemptToDeriveHardenedPublicKey
        }
        return hdKey.derive(child: index, harden: harden).serialized
    }

    /// Turns an extended private key into public one.
    /// - Parameter keyHex: The extended private key to neuter.
    /// - Returns: The corresponding extended public key.
    public static func neuterHDPrivateKey(key keyHex: String) throws -> String {
        guard let hdKey = HDExtendedKey(keyHex) else {
            throw WalletError.invalidExtendedKey
        }
        return (hdKey.isPrivate ? hdKey.neutered : hdKey).serialized
    }
    
    /// Creates a BIP39 mnemonic phrase.
    /// - Parameter entropyHex: The Base16 entropy from which the mnemonic is created. The length must be evenly divisible by 32 bits.
    /// - Returns: The generated sequence of words, each separated by a space character.
    public static func mnemonicNew(withEntropy entropyHex: String, language: String = "en") throws -> String {
        guard let entropy = Data(hex: entropyHex) else {
            throw WalletError.invalidHexString
        }
        guard let wordlist = mnemonicWordLists[language] else {
            throw WalletError.languageNotSupported
        }
        precondition(entropy.count >= mnemonicEntropyMin && entropy.count <= mnemonicEntropyMax && entropy.count % mnemonicEntropyMultiple == 0)
        let checksumBitCount = entropy.count / mnemonicEntropyMultiple
        guard let hashFirstByte = sha256(entropy).first else {
            preconditionFailure()
        }
        let discardChecksumBits = bitsPerByte - checksumBitCount
        let checksum = (hashFirstByte >> discardChecksumBits) << discardChecksumBits
        let entropyChecksumed = entropy + Data([checksum])
        let wordCount = (entropy.count * bitsPerByte + checksumBitCount) / bitsPerMnemonicWord
        var wordNumber = 0
        var wordIndices = [Int]()
        while wordNumber < wordCount {
            let bitsConsumed = wordNumber * bitsPerMnemonicWord
            let bitsInFirstByte = bitsPerByte - (bitsConsumed % bitsPerByte)
            let bitsInSecondOrThirdByte = (bitsPerMnemonicWord - bitsInFirstByte) % bitsPerByte
            let bitsInLastByte = bitsInSecondOrThirdByte == 0 ? bitsPerByte : bitsInSecondOrThirdByte
            let bytes = (bitsInFirstByte > 0 ? 1 : 0) + (bitsInSecondOrThirdByte > 0 ? 1 : 0) + (bitsPerMnemonicWord - bitsInFirstByte) / bitsPerByte
            let startIndex = entropyChecksumed.startIndex.advanced(by: bitsConsumed / bitsPerByte)
            let endIndex = startIndex.advanced(by: bytes)
            let paddingBytes = MemoryLayout<UInt32>.size - bytes
            let paddedChunk = Data(repeating: 0x00, count: paddingBytes) + entropyChecksumed[startIndex ..< endIndex]
            let wordWithGarbage = paddedChunk.withUnsafeBytes {
                $0.loadUnaligned(as: UInt32.self)
            }.byteSwapped
            let dropBitsBegin = (bitsPerByte - bitsInFirstByte) + paddingBytes * bitsPerByte
            let dropBitsEnd = bitsPerByte - bitsInLastByte
            let wordIndex = (wordWithGarbage << dropBitsBegin) >> (dropBitsBegin + dropBitsEnd)
            wordIndices.append(Int(wordIndex))
            wordNumber += 1
        }
        return wordIndices.map { wordlist[$0] }.joined(separator: mnemonicSeparators[language] ?? " ")
    }

    public static func mnemonicToSeed(mnemonic: String, passphrase: String = "", language: String = "en") throws -> String {
        try mnemonicCheck(mnemonic: mnemonic, passphrase: passphrase, language: language)

        guard
            let password = mnemonic.decomposedStringWithCompatibilityMapping.data(using: .utf8),
            let salt = ("mnemonic" + passphrase).decomposedStringWithCompatibilityMapping.data(using: .utf8)
        else {
            throw WalletError.invalidMnemonicOrPassphraseEncoding
        }
        do {
            let keyDerivation = try PBKDF2<SHA512>(password: password, salt: salt, iterations: 2048, keyLength: 64)
            return Data(try keyDerivation.calculate()).hex
        } catch _ as PBKDF2Error {
            throw WalletError.invalidMnemonicOrPassphraseEncoding
        }
    }

    private static func mnemonicCheck(mnemonic: String, passphrase: String = "", language: String = "en") throws {
        guard let wordlist = mnemonicWordLists[language] else {
            throw WalletError.languageNotSupported
        }
        let mnemonicWords = mnemonic.split(separator: mnemonicSeparators[language] ?? " ")
        let wordIndices: [Int] = mnemonicWords.compactMap {
            wordlist.firstIndex(of: String($0))
        }
        guard mnemonicWords.count == wordIndices.count else {
            throw WalletError.mnemonicWordNotOnList
        }
        let checksumedEntropyBitCount = mnemonicWords.count * bitsPerMnemonicWord
        let bitsMultiple = mnemonicEntropyMultiple * bitsPerByte
        let aux = checksumedEntropyBitCount * bitsMultiple
        guard aux % (bitsMultiple + 1) == 0 else {
            throw WalletError.mnemonicInvalidLength
        }
        let entropyBitCount = aux / (bitsMultiple + 1)

        // Let's reconstruct the entropy.
        // For convenience lets call the word indices (positions on the master wordlist) simply _words_.
        let words = wordIndices.map { UInt16($0) }
        var checksumedEntropy = Data()
        var bits = 0
        while bits < words.count * bitsPerMnemonicWord {
            var wordIndex = bits / bitsPerMnemonicWord
            var wordBitsIn = bits % bitsPerMnemonicWord
            var buffer = UInt16(0)
            var bufferLevel = 0
            while bufferLevel < UInt16.bitWidth && wordIndex < words.count {
                var word = words[wordIndex]
                word = word << ((UInt16.bitWidth - bitsPerMnemonicWord) + wordBitsIn)
                word = word >> bufferLevel
                buffer |= word
                // Update variables
                let bitsAdded = min(UInt16.bitWidth - bufferLevel, bitsPerMnemonicWord - wordBitsIn)
                bufferLevel += bitsAdded
                wordBitsIn += bitsAdded
                if wordBitsIn == bitsPerMnemonicWord {
                    wordIndex += 1
                    wordBitsIn = 0
                }
            }
            checksumedEntropy += withUnsafeBytes(of: buffer.bigEndian) {
                Data($0)
            }
            bits += bufferLevel
        }
        let checksumedEntropyByteCount = checksumedEntropyBitCount / bitsPerByte + (checksumedEntropyBitCount % bitsPerByte == 0 ? 0 : 1)
        if checksumedEntropy.count > checksumedEntropyByteCount {
            checksumedEntropy = checksumedEntropy.dropLast(1)
        }
        guard let lastByte = checksumedEntropy.last else {
            preconditionFailure()
        }
        let checksumBitCount = entropyBitCount / (mnemonicEntropyMultiple * bitsPerByte)
        let checksum = lastByte >> (bitsPerByte - checksumBitCount)
        let entropy = checksumedEntropy.dropLast(1)
        guard let hashFirstByte = sha256(entropy).first else {
            preconditionFailure()
        }
        let checksumVerify = hashFirstByte >> (bitsPerByte - checksumBitCount)
        guard checksumVerify == checksum else {
            throw WalletError.invalidMnemonicChecksum
        }
    }
}
