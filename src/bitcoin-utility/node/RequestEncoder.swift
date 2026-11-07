import Foundation
import JSONRPC
import NIOCore

/// Client side request/response coder.
struct RequestEncoder: MessageToByteEncoder {
    typealias OutboundIn = JSONRPCRequest
    typealias OutboundOut = ByteBuffer

    func encode(data request: JSONRPCRequest, out: inout ByteBuffer) throws {
        try out.writeJSONEncodable(request)
    }
}
