import Foundation
import JSONRPC
import NIOCore
import NIOFoundationEssentialsCompat

struct ResponseEncoder: MessageToByteEncoder, Sendable {
    typealias OutboundIn = JSONRPCResponse
    typealias OutboundOut = ByteBuffer

    func encode(data response: OutboundIn, out: inout ByteBuffer) throws {
        try out.writeJSONEncodable(response)
    }
}
