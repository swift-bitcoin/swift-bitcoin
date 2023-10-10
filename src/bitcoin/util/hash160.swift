import Foundation

func hash160(_ data: Data) -> Data {
    RIPEMD160.hash(sha256(data))
}
