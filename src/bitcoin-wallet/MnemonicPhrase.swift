import Foundation
import BitcoinCrypto

private let bitsPerByte = UInt8.bitWidth
private let bitsPerMnemonicWord = 11
private let mnemonicEntropyMin = 16 // Bytes
private let mnemonicEntropyMax = 32 // Bytes
private let mnemonicEntropyMultiple = 4 // Bytes

private let mnemonicSeparators = [ "jp": "\u{3000}" /* "　" */]

private let mnemonicWordLists = ["cs": mnemonicWordList_cs, "fr": mnemonicWordList_fr, "it": mnemonicWordList_it, "ko": mnemonicWordList_ko, "pt": mnemonicWordList_pt, "en": mnemonicWordList_en, "es": mnemonicWordList_es, "jp": mnemonicWordList_jp, "zh": mnemonicWordList_zh, "zh-Hant": mnemonicWordList_zhHant]

/// BIP39
public struct MnemonicPhrase {

    public let mnemonic: String
    public let language: String

    public init(_ mnemonic: String, passphrase: String = "", language: String = "en") throws {
        self.mnemonic = mnemonic
        self.language = language
        try check(passphrase: passphrase)
    }

    /// Creates a BIP39 mnemonic phrase. The generated sequence of words, each separated by a space character.
    /// - Parameter entropy: The Base16 entropy from which the mnemonic is created. The length must be evenly divisible by 32 bits.
    /// - Parameter language: Language ISO code (e.g. "en", "es", "jp")
    public init(entropy: Data, language: String = "en") throws {
        self.language = language
        guard let wordlist = mnemonicWordLists[language] else {
            throw Error.languageNotSupported
        }
        precondition(entropy.count >= mnemonicEntropyMin && entropy.count <= mnemonicEntropyMax && entropy.count % mnemonicEntropyMultiple == 0)
        let checksumBitCount = entropy.count / mnemonicEntropyMultiple
        let hashFirstByte = Data(SHA256.hash(data: entropy)).first!
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
        mnemonic = wordIndices.map { wordlist[$0] }.joined(separator: mnemonicSeparators[language] ?? " ")
    }

    public func toSeed(passphrase: String = "") throws -> String {
        guard
            let password = mnemonic.decomposedStringWithCompatibilityMapping.data(using: .utf8),
            let salt = ("mnemonic" + passphrase).decomposedStringWithCompatibilityMapping.data(using: .utf8)
        else {
            throw Error.invalidMnemonicOrPassphraseEncoding
        }
        do {
            let keyDerivation = try PBKDF2<SHA512>(password: password, salt: salt, iterations: 2048, keyLength: 64)
            return Data(try keyDerivation.calculate()).hex
        } catch _ as PBKDF2<SHA512>.Error {
            throw Error.invalidMnemonicOrPassphraseEncoding
        }
    }

    private func check(passphrase: String = "") throws {
        guard let wordlist = mnemonicWordLists[language] else {
            throw Error.languageNotSupported
        }
        let mnemonicWords = mnemonic.split(separator: mnemonicSeparators[language] ?? " ")
        let wordIndices: [Int] = mnemonicWords.compactMap {
            wordlist.firstIndex(of: String($0))
        }
        guard mnemonicWords.count == wordIndices.count else {
            throw Error.mnemonicWordNotOnList
        }
        let checksumedEntropyBitCount = mnemonicWords.count * bitsPerMnemonicWord
        let bitsMultiple = mnemonicEntropyMultiple * bitsPerByte
        let aux = checksumedEntropyBitCount * bitsMultiple
        guard aux % (bitsMultiple + 1) == 0 else {
            throw Error.mnemonicInvalidLength
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
        let lastByte = checksumedEntropy.last!
        let checksumBitCount = entropyBitCount / (mnemonicEntropyMultiple * bitsPerByte)
        let checksum = lastByte >> (bitsPerByte - checksumBitCount)
        let entropy = checksumedEntropy.dropLast(1)
        let hashFirstByte = Data(SHA256.hash(data: entropy)).first!
        let checksumVerify = hashFirstByte >> (bitsPerByte - checksumBitCount)
        guard checksumVerify == checksum else {
            throw Error.invalidMnemonicChecksum
        }
    }
}

public extension MnemonicPhrase {
    enum Error: Swift.Error {

        /// Mnemonic word list language not supported.
        case languageNotSupported

        case invalidMnemonicOrPassphraseEncoding

        /// Mnemonic contains an invalid word.
        case mnemonicWordNotOnList

        /// Mnemonic phrase needs to contain a valid number of words.
        case mnemonicInvalidLength

        /// Checksum calculated for nmemonic phrase does not match.
        case invalidMnemonicChecksum
    }
}
