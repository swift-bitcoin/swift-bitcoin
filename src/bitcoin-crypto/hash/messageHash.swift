import Foundation

public func messageHash(_ payload: Data) -> Data {
    hash256(messageMagic.data(using: .utf8)! + payload.varLenData)
}
