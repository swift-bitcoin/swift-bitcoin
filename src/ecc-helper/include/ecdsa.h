#ifndef ecdsa_h
#define ecdsa_h

#include <stdlib.h>
#include <secp256k1.h>

int ecdsa_signature_parse_der_lax(secp256k1_ecdsa_signature* sig, const unsigned char *input, size_t inputlen);
const int signECDSA(const secp256k1_context* ctx, u_char* sigOut, size_t* sigLenOut,const u_char* msg32, const u_char* secretKey32, const u_char grind);
const int verifyECDSA(const secp256k1_context* ctx, const u_char *sigBytes, const size_t sigLen, const u_char* msg32, const u_char* pubKey, const size_t pubKeyLen);
// const int verifyECDSASecretKey(const u_char *sigBytes, const size_t sigLen, const u_char* msg32, const u_char* secretKey32);
#endif /* ecdsa_h */
