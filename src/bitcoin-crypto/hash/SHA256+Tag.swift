public import protocol Foundation.DataProtocol
public import struct Crypto.SHA256

extension SHA256 {

    /// A BIP340 tag: `SHA256(tag) || SHA256(tag)` already absorbed into a hasher.
    ///
    /// `SHA256(SHA256(tag) || SHA256(tag) || message)` is the *tagged hash* of BIP340 and BIP341.
    /// The 64-byte prefix depends only on the tag, so a `Tag` computes it once and every hash
    /// starts from a copy of the saved hasher state instead of redoing two compressions.
    ///
    /// The library declares no tags of its own. Declare the ones your protocol uses as static
    /// constants in an extension (see `Examples/BitcoinTags.swift`).
    public struct Tag: Sendable {

        private let midstate: SHA256

        /// Creates a tag from its UTF-8 name, hashing the prefix once.
        public init(_ name: String) {
            let name = Array(name.utf8)
            let nameHash = SHA256.hash(bytes: name.span.bytes).copiedBytes
            var hasher = SHA256()
            hasher.update(bytes: nameHash.span.bytes)
            hasher.update(bytes: nameHash.span.bytes)
            midstate = hasher
        }

        /// A fresh hasher that has already absorbed the tag prefix.
        public func makeHasher() -> SHA256 { midstate }

        /// The tagged hash of `bytes`.
        public func hash(bytes: RawSpan) -> SHA256.Digest {
            var hasher = midstate
            hasher.update(bytes: bytes)
            return hasher.finalize()
        }

        /// The tagged hash of `data`.
        public func hash<D: DataProtocol>(data: D) -> SHA256.Digest {
            var hasher = midstate
            hasher.update(data: data)
            return hasher.finalize()
        }
    }

    /// Creates a hasher that has absorbed the BIP340 tag prefix for `tag`.
    ///
    /// Convenience that recomputes the prefix on every call. Prefer a ``Tag`` for repeated use.
    public init(tag: String) {
        self = Tag(tag).makeHasher()
    }

    /// The BIP340 tagged hash of `data`. Prefer a ``Tag`` for repeated use.
    public static func hash<D: DataProtocol>(data: D, tag: String) -> Digest {
        Tag(tag).hash(data: data)
    }
}
