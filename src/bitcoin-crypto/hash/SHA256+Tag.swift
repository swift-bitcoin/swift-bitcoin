import Foundation
import Crypto

/// Tagged hash introduced in BIP340.
public extension SHA256 {

    /// Initialized the hasher and updates it with the hash of the tag twice.
    ///
    /// If the tag cannot be decoded as a valid UTF-8 string, the hasher is _still_ initialized but it remains empty.
    /// 
    init(tag: String) {
        self.init()
        guard let tagData = tag.data(using: .utf8) else { return }
        let hashedTag = SHA256.hash(data: tagData)
        hashedTag.withUnsafeBytes {
            self.update(bufferPointer: $0)
            self.update(bufferPointer: $0)
        }
    }

    static func hash<D: DataProtocol>(data: D, tag: String) -> Digest {
        var hasher = SHA256(tag: tag)
        hasher.update(data: data)
        return hasher.finalize()
    }
}
