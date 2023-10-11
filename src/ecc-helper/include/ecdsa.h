#ifndef ecdsa_h
#define ecdsa_h

#include <stdlib.h>

const int signECDSA(u_char* sigOut, size_t* sigLenOut,const u_char* msg32, const u_char* secretKey32, const u_char grind);
const int verifyECDSA(const u_char *sigBytes, const size_t sigLen, const u_char* msg32, const u_char* pubKey, const size_t pubKeyLen);
// const int verifyECDSASecretKey(const u_char *sigBytes, const size_t sigLen, const u_char* msg32, const u_char* secretKey32);
#endif /* ecdsa_h */
