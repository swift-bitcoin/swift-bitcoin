import Foundation
import BitcoinCrypto

/// BIP342: The TapRoot Script (Tapscript) Common Message Extension as defined in BIP342
public struct TapscriptExtension: Equatable, Sendable {

    public init(tapLeafHash: Data, keyVersion: UInt8 = 0, codesepPos: UInt32 = 0xffffffff) {
        self.tapLeafHash = tapLeafHash
        self.keyVersion = keyVersion
        self.codesepPos = codesepPos
    }

    // We define the tapscript message extension ext to BIP341 Common Signature Message, indicated by ext_flag = 1:
    let tapLeafHash: Data // tapleaf_hash (32): the tapleaf hash as defined in BIP341
    let keyVersion: UInt8 // key_version (1): a constant value 0x00 representing the current version of public keys in the tapscript signature opcode execution.
    let codesepPos: UInt32 // codesep_pos (4): the opcode position of the last executed OP_CODESEPARATOR before the currently executed signature opcode, with the value in little endian (or 0xffffffff if none executed). The first opcode in a script has a position of 0. A multi-byte push opcode is counted as one opcode, regardless of the size of data being pushed. Opcodes in parsed but unexecuted branches count towards this value as well
}

extension TapscriptExtension: BinaryEncodable {

    /// Records the size which is always 37 bytes.
    public func countBytes(into counter: inout BitcoinCrypto.BinarySizeCounter, format: Never?) {
        counter.count(tapLeafHash)
        counter.countSize(1)
        counter.count(UInt32.self)
    }

    public func encode(into out: inout OutputRawSpan, format: Never?) throws {
        out.append(contentsOf: tapLeafHash)
        out.append(keyVersion)
        out.append(codesepPos, as: UInt32.self, .littleEndian)
    }

    /*
    public func encode(into encoder: inout BitcoinCrypto.BinaryEncoder, format: Never?) {
        encoder.encode(tapLeafHash)
        encoder.encode(keyVersion)
        encoder.encode(codesepPos)
    }
    */
}
