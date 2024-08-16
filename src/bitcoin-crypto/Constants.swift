// import LibSECP256k1

/// Text used to signify that a signed message follows and to prevent inadvertently signing a transaction.
let messageMagic = "\u{18}Bitcoin Signed Message:\n"

let secretKeySize = 32
let uncompressedPublicKeySize = 65
let compressedPublicKeySize = 33

let messageHashSize = 32

let ecdsaSignatureMaxSize = 72
let recoverableSignatureSize = 65
let compactSignatureSize = 64
let schnorrSignatureSize = 64

// public let publicKeySerializationTagEven = UInt8(SECP256K1_TAG_PUBKEY_EVEN)
// public let publicKeySerializationTagOdd = UInt8(SECP256K1_TAG_PUBKEY_ODD)
