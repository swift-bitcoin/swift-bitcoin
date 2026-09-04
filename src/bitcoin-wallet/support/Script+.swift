import BitcoinBase
import BitcoinCrypto

extension Script {

    var isPayToPubkey: Bool {
        if (binarySize == PublicKey.compressedLength + 2 || binarySize == PublicKey.uncompressedLength + 2),
           ops.count == 2,
           case .pushBytes(_) = ops[0],
           ops[1] == .checkSig { true } else { false }
    }

    package var isPayToPubkeyHash: Bool {
        if binarySize == RIPEMD160.Digest.byteCount + 5,
           ops.count == 5,
           ops[0] == .dup,
           ops[1] == .hash160,
           case .pushBytes(_) = ops[2],
           ops[3] == .equalVerify,
           ops[4] == .checkSig { true } else { false }
    }

    package var isPayToMultisig: Bool {
        guard
            ops.count >= 5, unparsable.isEmpty,
            case .constant(let m) = ops[0],
            case .constant(let n) = ops[ops.count - 2],
            m <= n,
            ops[ops.count - 1] == .checkMultisig,
            ops.count == 3 + n
        else { return false }
        return ops[1 ..< (ops.count - 2)].allSatisfy {
            if case .pushBytes(let key) = $0, (
                key.count == PublicKey.compressedLength ||
                key.count == PublicKey.uncompressedLength
            ) { true } else { false }
        }
    }

    var isPayToTaproot: Bool {
        if binarySize == PublicKey.xOnlyLength + 2,
           ops.count == 2,
           ops[0] == .constant(1),
           case .pushBytes(_) = ops[1] { true } else { false }
    }

    var isPayToWitnessKeyHash: Bool {
        if binarySize == RIPEMD160.Digest.byteCount + 2,
           ops.count == 2,
           ops[0] == .zero,
           case .pushBytes(_) = ops[1] { true } else { false }
    }

    var isPayToWitnessScriptHash: Bool {
        if binarySize == SHA256.Digest.byteCount + 2,
           ops.count == 2,
           ops[0] == .zero,
           case .pushBytes(_) = ops[1] { true } else { false }
    }
}
