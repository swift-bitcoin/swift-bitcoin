import Foundation
import BitcoinCrypto

/// Segregated Witness Address encoder/decoder
enum SegwitAddrCoder {

    /// Convert from one power-of-2 number base to another
    private static func convertBits(from: Int, to: Int, pad: Bool, idata: Data) throws -> Data {
        var acc: Int = 0
        var bits: Int = 0
        let maxv: Int = (1 << to) - 1
        let maxAcc: Int = (1 << (from + to - 1)) - 1
        var odata = Data()
        for ibyte in idata {
            acc = ((acc << from) | Int(ibyte)) & maxAcc
            bits += from
            while bits >= to {
                bits -= to
                odata.append(UInt8((acc >> bits) & maxv))
            }
        }
        if pad {
            if bits != 0 {
                odata.append(UInt8((acc << (to - bits)) & maxv))
            }
        } else if (bits >= from || ((acc << (to - bits)) & maxv) != 0) {
            throw Error.bitsConversionFailed
        }
        return odata
    }

    /// Decode segwit address
    static func decode(hrp: String, addr: String) throws -> (version: Int, program: Data) {
        let dec = try Bech32Decoder().decode(addr)
        guard dec.hrp == hrp else {
            throw Error.hrpMismatch(dec.hrp, hrp)
        }
        guard !dec.checksum.isEmpty else {
            throw Error.checksumSizeTooLow
        }
        let conv = try convertBits(from: 5, to: 8, pad: false, idata: dec.checksum.advanced(by: 1))
        guard conv.count >= 2 && conv.count <= 40 else {
            throw Error.dataSizeMismatch(conv.count)
        }
        guard dec.checksum[0] <= 16 else {
            throw Error.segwitVersionNotSupported(dec.checksum[0])
        }
        if dec.checksum[0] == 0 && conv.count != 20 && conv.count != 32 {
            throw Error.segwitV0ProgramSizeMismatch(conv.count)
        }
        guard dec.checksum[0] == 0 && !dec.bech32m || (dec.checksum[0] > 0 && dec.bech32m) else {
            throw Error.invalidBech32Variant(dec.bech32m ? "bech32m" : "bech32")
        }
        return (Int(dec.checksum[0]), conv)
    }

    /// Encode segwit address
    static func encode(hrp: String, version: Int, program: Data) throws -> String {
        var enc = Data([UInt8(version)])
        enc.append(try convertBits(from: 8, to: 5, pad: true, idata: program))
        let result = Bech32Encoder(bech32m: version > 0).encode(hrp, values: enc)
        guard let _ = try? decode(hrp: hrp, addr: result) else {
            throw Error.encodingCheckFailed
        }
        return result
    }
}

extension SegwitAddrCoder {
    enum Error: LocalizedError {
        case bitsConversionFailed,
             hrpMismatch(String, String),
             checksumSizeTooLow,
             dataSizeMismatch(Int),
             segwitVersionNotSupported(UInt8),
             segwitV0ProgramSizeMismatch(Int),
             encodingCheckFailed,
             invalidBech32Variant(String)

        var errorDescription: String {
            switch self {
            case .bitsConversionFailed:
                "Failed to perform bits conversion"
            case .checksumSizeTooLow:
                "Checksum size is too low"
            case .dataSizeMismatch(let size):
                "Program size \(size) does not meet required range 2...40"
            case .encodingCheckFailed:
                "Failed to check result after encoding"
            case .hrpMismatch(let got, let expected):
                "Human-readable-part \"\(got)\" does not match requested \"\(expected)\""
            case .segwitV0ProgramSizeMismatch(let size):
                "Segwit program size \(size) does not meet version 0 requirments"
            case .segwitVersionNotSupported(let version):
                "Segwit version \(version) is not supported by this decoder"
            case .invalidBech32Variant(let version):
                "The variant used (Bech32 vs Bech32m) is invalid for the decoded witness version \(version)."
            }
        }
    }
}
