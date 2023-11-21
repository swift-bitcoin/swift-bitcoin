#include "ecdsa.h"
#include "ecc.h"

#include <stdint.h>
#include <assert.h>
#include <string.h>

extern secp256k1_context* secp256k1_context_sign;

#ifndef htobe32
uint32_t htobe32(uint32_t x) /* aka bswap_32 */
{
    return (((x & 0xff000000U) >> 24) | ((x & 0x00ff0000U) >>  8) |
            ((x & 0x0000ff00U) <<  8) | ((x & 0x000000ffU) << 24));
}
#endif

void WriteLE32(u_char* ptr, uint32_t x)
{
    uint32_t v = htobe32(x);
    memcpy(ptr, (char*)&v, 4);
}

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
int ecdsa_signature_parse_der_lax(secp256k1_ecdsa_signature* sig, const unsigned char *input, size_t inputlen) {
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

// Check that the sig has a low R value and will be less than 71 bytes
char SigHasLowR(const secp256k1_ecdsa_signature* sig)
{
    secp256k1_context *context = secp256k1_context_create(SECP256K1_CONTEXT_SIGN);
    u_char compact_sig[64];
    secp256k1_ecdsa_signature_serialize_compact(context, compact_sig, sig);

    // In DER serialization, all values are interpreted as big-endian, signed integers. The highest bit in the integer indicates
    // its signed-ness; 0 is positive, 1 is negative. When the value is interpreted as a negative integer, it must be converted
    // to a positive value by prepending a 0x00 byte so that the highest bit is 0. We can avoid this prepending by ensuring that
    // our highest bit is always 0, and thus we must check that the first byte is less than 0x80.
    return compact_sig[0] < 0x80;
}

const int signECDSA(u_char* sigOut, size_t* sigLenOut, const u_char* msg32, const u_char* secretKey32, const u_char grind) {
    const size_t SIGNATURE_SIZE = 72;
    const u_char test_case = 0;

    u_char extra_entropy[32] = {0};
    WriteLE32(extra_entropy, test_case);
    secp256k1_ecdsa_signature sig;
    uint32_t counter = 0;
    int ret = secp256k1_ecdsa_sign(secp256k1_context_sign, &sig, msg32, secretKey32, secp256k1_nonce_function_rfc6979, (!grind && test_case) ? extra_entropy : NULL);
    // Grind for low R
    while (ret && !SigHasLowR(&sig) && grind) {
        WriteLE32(extra_entropy, ++counter);
        ret = secp256k1_ecdsa_sign(secp256k1_context_sign,  &sig, msg32, secretKey32, secp256k1_nonce_function_rfc6979, extra_entropy);
    }
    assert(ret);
    size_t sigLen = SIGNATURE_SIZE;
    u_char *sigBytes = malloc(sigLen);
    ret = secp256k1_ecdsa_signature_serialize_der(secp256k1_context_sign, sigBytes, &sigLen, &sig);
    assert(ret);
    // Additional verification step to prevent using a potentially corrupted signature
    secp256k1_pubkey pk;
    ret = secp256k1_ec_pubkey_create(secp256k1_context_sign, &pk, secretKey32);
    assert(ret);
    ret = secp256k1_ecdsa_verify(secp256k1_context_static, &sig, msg32, &pk);
    assert(ret);
    memcpy(sigOut, sigBytes, sigLen);
    *sigLenOut = sigLen;
    return 1;
}

const int verifyECDSA(const u_char *sigBytes, const size_t sigLen, const u_char* msg32, const u_char* pubKey, const size_t pubKeyLen) {
    secp256k1_context *secp256k1_context_verify = secp256k1_context_create(SECP256K1_CONTEXT_VERIFY);

    secp256k1_ecdsa_signature sig;
    if (!ecdsa_signature_parse_der_lax(&sig, sigBytes, sigLen)) {
        return 0;
    }

    secp256k1_ecdsa_signature sigNorm;
    int wasNormalized = secp256k1_ecdsa_signature_normalize(secp256k1_context_static, &sigNorm, &sig);

    secp256k1_pubkey pk;
    if (!secp256k1_ec_pubkey_parse(secp256k1_context_verify, &pk, pubKey, pubKeyLen)) {
        return 0;
    }
    int isValid = secp256k1_ecdsa_verify(secp256k1_context_verify, &sigNorm, msg32, &pk);
    return isValid;
}

const int verifyECDSASecretKey(const u_char *sigBytes, const size_t sigLen, const u_char* msg32, const u_char* secretKey32) {
    secp256k1_context *secp256k1_context_verify = secp256k1_context_create(SECP256K1_CONTEXT_VERIFY);

    secp256k1_ecdsa_signature sig;
    int ret = secp256k1_ecdsa_signature_parse_der(secp256k1_context_static, &sig, sigBytes, sigLen);
    assert(ret);
    secp256k1_pubkey pk;
    ret = secp256k1_ec_pubkey_create(secp256k1_context_sign, &pk, secretKey32);
    assert(ret);
    ret = secp256k1_ecdsa_verify(secp256k1_context_verify, &sig, msg32, &pk);
    return ret;
}
