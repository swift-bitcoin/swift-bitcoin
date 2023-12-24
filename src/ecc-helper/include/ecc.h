#ifndef ecc_h
#define ecc_h

#include <stdlib.h>
#include <secp256k1.h>

secp256k1_context* secp256k1_context_sign;

static const size_t KEY_LEN = 32;
static const size_t PUBKEY_MAX_LEN = 65; // Uncompressed
static const size_t PUBKEY_COMPRESSED_LEN = 33;

int createSecretKey(void (*getRandBytes)(u_char*, const size_t), u_char *secretKeyOut32, size_t* secretKeyLenOut);
int getPublicKey(u_char *pubKeyOut, size_t* pubKeyLenOut, const u_char *secretKey32, const int compress);
#endif /* ecc_h */
