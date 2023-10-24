import Foundation

func getRandBytes(_ byteCount: Int) -> Data {
    var bytes = [UInt8](repeating: 0, count: byteCount)
    for i in bytes.indices {
        bytes[i] = .random(in: UInt8.min...UInt8.max)
    }
    return Data(bytes)
}

func getRandBytesExtern(_ bytesOut: UnsafeMutablePointer<UInt8>!, _ byteCount: Int) {
    let byteCountInt = Int(byteCount)
    let resultData = getRandBytes(byteCountInt)
    resultData.copyBytes(to: bytesOut, from: 0 ..< byteCountInt)
}
