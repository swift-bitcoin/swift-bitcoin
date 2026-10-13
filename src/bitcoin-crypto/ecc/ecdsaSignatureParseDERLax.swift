import Foundation
import CSECP256K1

/** This function is taken from the libsecp256k1 distribution and implements
 *  DER parsing for ECDSA signatures, while supporting an arbitrary subset of
 *  format violations.
 *
 *  Supported violations include negative integers, excessive padding, garbage
 *  at the end, and overly long length descriptors. This is safe to use in
 *  Bitcoin because since the activation of BIP66, signatures are verified to be
 *  strict DER before being passed to this module, and we know it supports all
 *  violations present in the blockchain before that point.
 */
func ecdsaSignatureParseDERLax(_ input: Data) -> CSECP256K1::ECDSASignature? {
    let inputlen = input.count

    var rpos: Int
    var rlen: Int
    var spos: Int
    var slen: Int
    var pos = 0
    var lenbyte: UInt8
    var tmpsig = InlineArray<64, UInt8>.init(repeating: 0)
    //var tmpsig = [UInt8](repeating: 0, count: 64)
    var overflow = false

    /* Hack to initialize sig with a correctly-parsed but invalid signature. */
    var sig = CollectionOfOne(CSECP256K1::ECDSASignature()); var sigSpan = sig.mutableSpan
    _ = SECP256K1Context.shared.ecdsaSignatureParseCompact(&sigSpan, compact: tmpsig.span) // secp256k1_ecdsa_signature_parse_compact(secp256k1_context_static, sig, tmpsig);

    /* Sequence tag byte */
    if pos == inputlen || input[pos] != 0x30 {
        return nil
    }
    pos += 1

    /* Sequence length bytes */
    if pos == inputlen {
        return nil
    }
    lenbyte = input[pos]; pos += 1

    if lenbyte & 0x80 != 0 {
        lenbyte -= 0x80
        if lenbyte > inputlen - pos {
            return nil
        }
        pos += Int(lenbyte)
    }

    /* Integer tag byte for R */
    if pos == inputlen || input[pos] != 0x02 {
        return nil
    }
    pos += 1

    /* Integer length for R */
    if (pos == inputlen) {
        return nil
    }
    lenbyte = input[pos]; pos += 1
    if lenbyte & 0x80 != 0 {
        lenbyte -= 0x80
        if lenbyte > inputlen - pos {
            return nil
        }
        while lenbyte > 0 && input[pos] == 0 {
            pos += 1
            lenbyte -= 1
        }
        precondition(MemoryLayout<size_t>.size >= 4, "size_t too small")
        if lenbyte >= 4 {
            return nil
        }
        rlen = 0;
        while lenbyte > 0 {
            rlen = (rlen << 8) + Int(input[pos])
            pos += 1
            lenbyte -= 1
        }
    } else {
        rlen = Int(lenbyte)
    }
    if rlen > inputlen - pos {
        return nil
    }
    rpos = pos
    pos += rlen

    /* Integer tag byte for S */
    if pos == inputlen || input[pos] != 0x02 {
        return nil
    }
    pos += 1

    /* Integer length for S */
    if pos == inputlen {
        return nil
    }
    lenbyte = input[pos]; pos += 1
    if lenbyte & 0x80 != 0 {
        lenbyte -= 0x80
        if lenbyte > inputlen - pos {
            return nil
        }
        while lenbyte > 0 && input[pos] == 0 {
            pos += 1
            lenbyte -= 1
        }
        precondition(MemoryLayout<size_t>.size >= 4, "size_t too small")
        if lenbyte >= 4 {
            return nil
        }
        slen = 0
        while lenbyte > 0 {
            slen = (slen << 8) + Int(input[pos])
            pos += 1
            lenbyte -= 1
        }
    } else {
        slen = Int(lenbyte)
    }
    if slen > inputlen - pos {
        return nil
    }
    spos = pos

    /* Ignore leading zeroes in R */
    while rlen > 0 && input[rpos] == 0 {
        rlen -= 1
        rpos += 1
    }
    /* Copy R value */
    if rlen > 32 {
        overflow = true
    } else {
        //memcpy(tmpsig + 32 - rlen, input + rpos, rlen);
        var tmpSigMutable = tmpsig.mutableSpan
        var tmpSigRaw = tmpSigMutable.mutableBytes
        tmpSigRaw.updateSubrange((32 - rlen)..<32, copying: input.span.bytes.extracting(rpos..<(rpos + rlen)))
        //tmpsig.replaceSubrange((32 - rlen)..<32, with: input[rpos..<(rpos + rlen)])
    }

    /* Ignore leading zeroes in S */
    while slen > 0 && input[spos] == 0 {
        slen -= 1
        spos += 1
    }
    /* Copy S value */
    if slen > 32 {
        overflow = true
    } else {
        //memcpy(tmpsig + 64 - slen, input + spos, slen);
        var tmpSigMutable = tmpsig.mutableSpan
        var tmpSigRaw = tmpSigMutable.mutableBytes
        tmpSigRaw.updateSubrange((64 - slen)..<64, copying: input.span.bytes.extracting(spos..<(spos + slen)))
        //tmpsig.replaceSubrange((64 - slen)..<64, with: input[spos..<(spos + slen)])
    }

    if !overflow {
        overflow = SECP256K1Context.shared.ecdsaSignatureParseCompact(&sigSpan, compact: tmpsig.span) == 0 // overflow = !secp256k1_ecdsa_signature_parse_compact(secp256k1_context_static, sig, tmpsig);
    }
    if overflow {
        /* Overwrite the result again with a correctly-parsed but invalid
         signature if parsing failed. */

        var tmpsigSpan = tmpsig.mutableSpan; tmpsigSpan.update(repeating: 0) // memset(tmpsig, 0, 64);

        _ = SECP256K1Context.shared.ecdsaSignatureParseCompact(&sigSpan, compact: tmpsig.span) // secp256k1_ecdsa_signature_parse_compact(secp256k1_context_static, sig, tmpsig);
    }
    return sig[0]
}

/*
int ecdsa_signature_parse_der_lax(secp256k1_ecdsa_signature* sig, const unsigned char *__counted_by(inputLen)
                                  input __noescape, size_t inputlen) {
    size_t rpos, rlen, spos, slen;
    size_t pos = 0;
    size_t lenbyte;
    unsigned char tmpsig[64] = {0};
    int overflow = 0;

    /* Hack to initialize sig with a correctly-parsed but invalid signature. */
    secp256k1_ecdsa_signature_parse_compact(secp256k1_context_static, sig, tmpsig);

    /* Sequence tag byte */
    if (pos == inputlen || input[pos] != 0x30) {
        return 0;
    }
    pos++;

    /* Sequence length bytes */
    if (pos == inputlen) {
        return 0;
    }
    lenbyte = input[pos++];
    if (lenbyte & 0x80) {
        lenbyte -= 0x80;
        if (lenbyte > inputlen - pos) {
            return 0;
        }
        pos += lenbyte;
    }

    /* Integer tag byte for R */
    if (pos == inputlen || input[pos] != 0x02) {
        return 0;
    }
    pos++;

    /* Integer length for R */
    if (pos == inputlen) {
        return 0;
    }
    lenbyte = input[pos++];
    if (lenbyte & 0x80) {
        lenbyte -= 0x80;
        if (lenbyte > inputlen - pos) {
            return 0;
        }
        while (lenbyte > 0 && input[pos] == 0) {
            pos++;
            lenbyte--;
        }
        static_assert(sizeof(size_t) >= 4, "size_t too small");
        if (lenbyte >= 4) {
            return 0;
        }
        rlen = 0;
        while (lenbyte > 0) {
            rlen = (rlen << 8) + input[pos];
            pos++;
            lenbyte--;
        }
    } else {
        rlen = lenbyte;
    }
    if (rlen > inputlen - pos) {
        return 0;
    }
    rpos = pos;
    pos += rlen;

    /* Integer tag byte for S */
    if (pos == inputlen || input[pos] != 0x02) {
        return 0;
    }
    pos++;

    /* Integer length for S */
    if (pos == inputlen) {
        return 0;
    }
    lenbyte = input[pos++];
    if (lenbyte & 0x80) {
        lenbyte -= 0x80;
        if (lenbyte > inputlen - pos) {
            return 0;
        }
        while (lenbyte > 0 && input[pos] == 0) {
            pos++;
            lenbyte--;
        }
        static_assert(sizeof(size_t) >= 4, "size_t too small");
        if (lenbyte >= 4) {
            return 0;
        }
        slen = 0;
        while (lenbyte > 0) {
            slen = (slen << 8) + input[pos];
            pos++;
            lenbyte--;
        }
    } else {
        slen = lenbyte;
    }
    if (slen > inputlen - pos) {
        return 0;
    }
    spos = pos;

    /* Ignore leading zeroes in R */
    while (rlen > 0 && input[rpos] == 0) {
        rlen--;
        rpos++;
    }
    /* Copy R value */
    if (rlen > 32) {
        overflow = 1;
    } else {
        memcpy(tmpsig + 32 - rlen, input + rpos, rlen);
    }

    /* Ignore leading zeroes in S */
    while (slen > 0 && input[spos] == 0) {
        slen--;
        spos++;
    }
    /* Copy S value */
    if (slen > 32) {
        overflow = 1;
    } else {
        memcpy(tmpsig + 64 - slen, input + spos, slen);
    }

    if (!overflow) {
        overflow = !secp256k1_ecdsa_signature_parse_compact(secp256k1_context_static, sig, tmpsig);
    }
    if (overflow) {
        /* Overwrite the result again with a correctly-parsed but invalid
         signature if parsing failed. */
        memset(tmpsig, 0, 64);
        secp256k1_ecdsa_signature_parse_compact(secp256k1_context_static, sig, tmpsig);
    }
    return 1;
}
*/
