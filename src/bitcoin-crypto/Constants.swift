/// Text used to signify that a signed message follows and to prevent inadvertently signing a transaction.
let messageMagic = "\u{18}Bitcoin Signed Message:\n"

let secretKeySize = 32
let messageHashSize = 32
let signatureSize = 72
let compactSignatureSize = 65
let uncompressedKeySize = 65
let compressedKeySize = 33

let taprootControlBaseSize = 33
let taprootControlNodeSize = 32
