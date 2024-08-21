 import LibSECP256k1

/// Text used to signify that a signed message follows and to prevent inadvertently signing a transaction.
let messageMagic = "\u{18}Bitcoin Signed Message:\n"

public let publicKeySerializationTagEven = UInt8(SECP256K1_TAG_PUBKEY_EVEN)
public let publicKeySerializationTagOdd = UInt8(SECP256K1_TAG_PUBKEY_ODD)
public let publicKeySerializationTagUncompressed = UInt8(SECP256K1_TAG_PUBKEY_UNCOMPRESSED)

