import Foundation
import NIOCore
import NIOFoundationCompat
import JSONRPC

/// Client side request/response coder.
struct ResponseDecoder: ByteToMessageDecoder {

    typealias InboundIn = ByteBuffer
    typealias InboundOut = JSONRPCResponse

    let method: String

    func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        guard buffer.readableBytes > 0 else {
            // TODO: Figure out why we are getting called with 0-length data.
            return .needMoreData
        }

        let data = buffer.readData(length: buffer.readableBytes)!
        let decoder = JSONDecoder()
        decoder.userInfo[.method] = method
        let decodable = try decoder.decode(JSONRPCResponse.self, from: data)
        context.fireChannelRead(wrapInboundOut(decodable))
        return .continue
    }
}
