import Foundation
import BitcoinCrypto

private let bitsPerByte = UInt8.bitWidth
private let bitsPerMnemonicWord = 11
private let mnemonicEntropyMin = 16 // Bytes
private let mnemonicEntropyMax = 32 // Bytes
private let mnemonicEntropyMultiple = 4 // Bytes

private let mnemonicSeparators = [ "jp": "\u{3000}" /* "　" */]

private let mnemonicWordLists = ["cs": mnemonicWordList_cs, "fr": mnemonicWordList_fr, "it": mnemonicWordList_it, "ko": mnemonicWordList_ko, "pt": mnemonicWordList_pt, "en": mnemonicWordList_en, "es": mnemonicWordList_es, "jp": mnemonicWordList_jp, "zh": mnemonicWordList_zh, "zh-Hant": mnemonicWordList_zhHant]

public struct MnemonicPhrase {

    public let mnemonic: String
    public let language: String

    // TODO: Throw instead
    public init?(_ mnemonic: String, passphrase: String = "", language: String = "en") {
        self.mnemonic = mnemonic
        self.language = language
        do {
            try check(passphrase: passphrase)
        } catch {
            return nil
        }
    }

    /// Creates a BIP39 mnemonic phrase.
    /// - Parameter entropyHex: The Base16 entropy from which the mnemonic is created. The length must be evenly divisible by 32 bits.
    /// - Parameter language: Language ISO code (e.g. "en", "es", "jp")
    /// - Returns: The generated sequence of words, each separated by a space character.
    public init(entropy: Data, language: String = "en") throws {
//        guard let entropy = Data(hex: entropyHex) else {
//            throw WalletError.invalidHexString
//        }
        self.language = language
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
        mnemonic = wordIndices.map { wordlist[$0] }.joined(separator: mnemonicSeparators[language] ?? " ")
    }

    public func toSeed(passphrase: String = "") throws -> String {
        guard
            let password = mnemonic.decomposedStringWithCompatibilityMapping.data(using: .utf8),
            let salt = ("mnemonic" + passphrase).decomposedStringWithCompatibilityMapping.data(using: .utf8)
        else {
            throw WalletError.invalidMnemonicOrPassphraseEncoding
        }
        do {
            let keyDerivation = try PBKDF2SHA512(password: password, salt: salt, iterations: 2048, keyLength: 64)
            return Data(try keyDerivation.calculate()).hex
        } catch _ as PBKDF2Error {
            // TODO: Throw MnemonicPhrase-specific errors
            throw WalletError.invalidMnemonicOrPassphraseEncoding
        }
    }

    private func check(passphrase: String = "") throws {
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
