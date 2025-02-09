import Foundation
import NIOCore
import NIOFoundationCompat

private let maxPayload = 1_000_000 // 1MB

// no delimeter is provided, brute force try to decode the json
public struct BruteForceCodec<T>: ByteToMessageDecoder, MessageToByteEncoder where T: Decodable {
    public typealias InboundIn = ByteBuffer
    public typealias InboundOut = ByteBuffer
    public typealias OutboundIn = ByteBuffer
    public typealias OutboundOut = ByteBuffer

    private let last = UInt8(ascii: "}")
    private var lastIndex = 0

    public mutating func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        guard buffer.readableBytes < maxPayload else {
            throw CodecError.requestTooLarge
        }
        
        // try to find a payload by looking for a json payload, first rough cut is looking for a trailing }
        let readableBytesView = buffer.readableBytesView.dropFirst(self.lastIndex)
        guard let _ = readableBytesView.firstIndex(of: last) else {
            self.lastIndex = buffer.readableBytes
            return .needMoreData
        }
        
        // try to confirm its a json payload by brute force decoding
        let length = buffer.readableBytes
        let data = buffer.getData(at: buffer.readerIndex, length: length)!
        do {
            _ = try JSONDecoder().decode(T.self, from: data)
        } catch is DecodingError {
            self.lastIndex = buffer.readableBytes
            return .needMoreData
        }
        
        // slice the buffer
        let slice = buffer.readSlice(length: length)!
        self.lastIndex = 0
        // call next handler
        context.fireChannelRead(wrapInboundOut(slice))
        return .continue
    }

    public mutating func decodeLast(context: ChannelHandlerContext, buffer: inout ByteBuffer, seenEOF: Bool) throws -> DecodingState {
        while try self.decode(context: context, buffer: &buffer) == .continue {}
        if buffer.readableBytes > buffer.readerIndex {
            throw CodecError.badFraming
        }
        return .needMoreData
    }

    // outbound
    public func encode(data: OutboundIn, out: inout ByteBuffer) throws {
        var payload = data
        out.writeBuffer(&payload)
    }
}
