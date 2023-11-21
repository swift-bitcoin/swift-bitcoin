import Foundation

func computeMerkleRoot(controlBlock: Data, tapLeafHash: Data) -> Data {
    let pathLen = (controlBlock.count - 33) / 32
    var k = tapLeafHash
    for i in 0 ..< pathLen {
        let startIndex = controlBlock.startIndex.advanced(by: 33 + 32 * i)
        let endIndex = startIndex + 31
        let node = controlBlock[startIndex ... endIndex]
        let payload = k.hex < node.hex ? k + node : node + k
        k = taggedHash(tag: "TapBranch", payload: payload)
    }
    return k
}
