import Foundation

func writeLE32(_ destination: inout [UInt8], _ x: UInt32) {
    precondition(destination.count >= 4)
    var v = x.littleEndian // On LE platforms this line does nothing
    assert(v == x) // Remove once we are ready to try BE platform
    withUnsafeBytes(of: &v) {
        destination.replaceSubrange(0..<4, with: $0)
    }
}
