#ifndef ecdsa_h
#define ecdsa_h

#include <secp256k1.h>

int ecdsa_signature_parse_der_lax(secp256k1_ecdsa_signature* sig, const unsigned char *input, size_t inputlen);

#endif /* ecdsa_h */
