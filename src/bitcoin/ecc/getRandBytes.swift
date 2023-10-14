import Foundation
import ECCHelper

func getRandBytes(_ byteCount: Int) -> Data {
    var bytes = [UInt8](repeating: 0, count: byteCount)
    let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
    precondition(status == errSecSuccess)
    return Data(bytes)
}

func getRandBytesExtern(_ bytesOut: UnsafeMutablePointer<UInt8>!, _ byteCount: Int) {
    let byteCountInt = Int(byteCount)
    let resultData = getRandBytes(byteCountInt)
    resultData.copyBytes(to: bytesOut, from: 0 ..< byteCountInt)
}
