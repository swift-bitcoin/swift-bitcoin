#include "ecc.h"

#include <assert.h>
#include <string.h>

int getPublicKey(const secp256k1_context* ctx, u_char *pubKeyOut, size_t* pubKeyLenOut, const u_char *secretKey32, const int compress) {
    assert(secp256k1_context_static != NULL);
    secp256k1_pubkey pubKey;
    if (!secp256k1_ec_pubkey_create(ctx, &pubKey, secretKey32)) return 0;
    size_t pubKeyLen = PUBKEY_MAX_LEN;
    u_char* pubKeyData = malloc(pubKeyLen);
    int result = secp256k1_ec_pubkey_serialize(secp256k1_context_static, pubKeyData, &pubKeyLen, &pubKey, compress ? SECP256K1_EC_COMPRESSED : SECP256K1_EC_UNCOMPRESSED);
    if (!result) return 0;
    memcpy(pubKeyOut, pubKeyData, pubKeyLen);
    *pubKeyLenOut = pubKeyLen;
    return result;
}
