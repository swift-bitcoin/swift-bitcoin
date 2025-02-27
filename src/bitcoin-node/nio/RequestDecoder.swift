import Foundation
import NIOCore
import JSONRPC

/// Server side response/request coder.
struct RequestDecoder: ByteToMessageDecoder, Sendable {

    typealias InboundIn = ByteBuffer
    typealias InboundOut = JSONRPCRequest

    func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        guard buffer.readableBytes > 0 else {
            // TODO: Figure out why we are getting called with 0-length data.
            return .needMoreData
        }

        let data = buffer.readData(length: buffer.readableBytes)!
        let decodable = try JSONDecoder().decode(InboundOut.self, from: data)
            context.fireChannelRead(wrapInboundOut(decodable))
        return .continue
    }
}
