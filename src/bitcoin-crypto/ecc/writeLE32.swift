import Foundation

// TODO: this entire helper might be an overkill. We probably do not even support big endian platforms.
func writeLE32(_ destination: inout [UInt8], _ x: UInt32) {
    precondition(destination.count >= 4)
    var v = x.littleEndian // On LE platforms this line does nothing
    assert(v == x) // Remove once we are ready to try BE platform
    withUnsafeBytes(of: &v) {
        destination.replaceSubrange(0..<4, with: $0)
    }
}
