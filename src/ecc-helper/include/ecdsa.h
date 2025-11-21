#ifndef ecdsa_h
#define ecdsa_h

#include <secp256k1.h>
#include <ptrcheck.h>
#include <lifetimebound.h>

int ecdsa_signature_parse_der_lax(secp256k1_ecdsa_signature* sig, const unsigned char * __counted_by(len)
                                  input __noescape, size_t len);

#endif /* ecdsa_h */
