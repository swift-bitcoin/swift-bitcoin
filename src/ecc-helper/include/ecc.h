#ifndef ecc_h
#define ecc_h

#include <stdlib.h>
#include <secp256k1.h>

static const size_t KEY_LEN = 32;
static const size_t PUBKEY_MAX_LEN = 65; // Uncompressed
static const size_t PUBKEY_COMPRESSED_LEN = 33;

int getPublicKey(const secp256k1_context* ctx, u_char *pubKeyOut, size_t* pubKeyLenOut, const u_char *secretKey32, const int compress);
#endif /* ecc_h */
