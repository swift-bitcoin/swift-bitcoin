import Foundation
import BitcoinCrypto

let taprootControlBaseSize = 33
let taprootControlNodeSize = 32

public func computeMerkleRoot(controlBlock: Data, tapLeafHash: Data) -> Data {
    let pathLen = (controlBlock.count - taprootControlBaseSize) / taprootControlNodeSize
    var k = tapLeafHash
    for i in 0 ..< pathLen {
        let startIndex = controlBlock.startIndex.advanced(by: taprootControlBaseSize + taprootControlNodeSize * i)
        let endIndex = startIndex.advanced(by: taprootControlNodeSize)
        let node = controlBlock[startIndex ..< endIndex]
        let payload = k.lexicographicallyPrecedes(node) ? k + node : node + k
        k = taggedHash(tag: "TapBranch", payload: payload)
    }
    return k
}
