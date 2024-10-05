import BitcoinBase
import BitcoinCrypto

extension BitcoinScript {

    var isPayToPublicKey: Bool {
        if (size == PublicKey.compressedLength + 2 || size == PublicKey.uncompressedLength + 2),
           operations.count == 2,
           case .pushBytes(_) = operations[0],
           operations[1] == .checkSig { true } else { false }
    }

    var isPayToPublicKeyHash: Bool {
        if size == RIPEMD160.Digest.byteCount + 5,
           operations.count == 5,
           operations[0] == .dup,
           operations[1] == .hash160,
           case .pushBytes(_) = operations[2],
           operations[3] == .equalVerify,
           operations[4] == .checkSig { true } else { false }
    }

    var isPayToMultisig: Bool {
        guard
            operations.count >= 5, unparsable.isEmpty,
            case .constant(let m) = operations[0],
            case .constant(let n) = operations[operations.count - 2],
            m <= n,
            operations[operations.count - 1] == .checkMultiSig,
            operations.count == 3 + n
        else { return false }
        return operations[1 ..< (operations.count - 2)].allSatisfy {
            if case .pushBytes(let key) = $0, (
                key.count == PublicKey.compressedLength ||
                key.count == PublicKey.uncompressedLength
            ) { true } else { false }
        }
    }

    var isPayToTaproot: Bool {
        if size == PublicKey.xOnlyLength + 2,
           operations.count == 2,
           operations[0] == .constant(1),
           case .pushBytes(_) = operations[1] { true } else { false }
    }

    var isPayToWitnessKeyHash: Bool {
        if size == RIPEMD160.Digest.byteCount + 2,
           operations.count == 2,
           operations[0] == .zero,
           case .pushBytes(_) = operations[1] { true } else { false }
    }

    var isPayToWitnessScriptHash: Bool {
        if size == SHA256.Digest.byteCount + 2,
           operations.count == 2,
           operations[0] == .zero,
           case .pushBytes(_) = operations[1] { true } else { false }
    }
}
