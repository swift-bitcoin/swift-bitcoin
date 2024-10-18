import NIOCore

private let maxPayload = 1_000_000 // 1MB

// aggregate bytes till delimiter and add delimiter at end
public final class NewlineEncoder: ByteToMessageDecoder, MessageToByteEncoder {

    public typealias InboundIn = ByteBuffer
    public typealias InboundOut = ByteBuffer
    public typealias OutboundIn = ByteBuffer
    public typealias OutboundOut = ByteBuffer

    public init() { }

    private let delimiter1 = UInt8(ascii: "\r")
    private let delimiter2 = UInt8(ascii: "\n")
    private var lastIndex = 0

    // inbound
    public func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        guard buffer.readableBytes < maxPayload else {
            throw CodecError.requestTooLarge
        }
        guard buffer.readableBytes >= 3 else {
            return .needMoreData
        }

        // try to find a payload by looking for a \r\n delimiter
        let readableBytesView = buffer.readableBytesView.dropFirst(self.lastIndex)
        guard let index = readableBytesView.firstIndex(of: delimiter2) else {
            self.lastIndex = buffer.readableBytes
            return .needMoreData
        }
        guard readableBytesView[index - 1] == delimiter1 else {
            return .needMoreData
        }

        // slice the buffer
        let length = index - buffer.readerIndex - 1
        let slice = buffer.readSlice(length: length)!
        buffer.moveReaderIndex(forwardBy: 2)
        self.lastIndex = 0
        // call next handler
        context.fireChannelRead(wrapInboundOut(slice))
        return .continue
    }

    public func decodeLast(context: ChannelHandlerContext, buffer: inout ByteBuffer, seenEOF: Bool) throws -> DecodingState {
        while try self.decode(context: context, buffer: &buffer) == .continue {}
        if buffer.readableBytes > buffer.readerIndex {
            throw CodecError.badFraming
        }
        return .needMoreData
    }

    // outbound
    public func encode(data: OutboundIn, out: inout ByteBuffer) throws {
        var payload = data
        // original data
        out.writeBuffer(&payload)
        // add delimiter
        out.writeBytes([delimiter1, delimiter2])
    }
}
