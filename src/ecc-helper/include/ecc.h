#ifndef ecc_h
#define ecc_h

#include <stdlib.h>
#include <secp256k1.h>

static const size_t KEY_LEN = 32;
static const size_t PUBKEY_MAX_LEN = 65; // Uncompressed
static const size_t PUBKEY_COMPRESSED_LEN = 33;

int createSecretKey(const secp256k1_context* ctx, void (*getRandBytes)(u_char*, const size_t), u_char *secretKeyOut32, size_t* secretKeyLenOut);
int getPublicKey(const secp256k1_context* ctx, u_char *pubKeyOut, size_t* pubKeyLenOut, const u_char *secretKey32, const int compress);
#endif /* ecc_h */
