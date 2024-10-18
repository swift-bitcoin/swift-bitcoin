import NIOCore

private let maxPayload = 1_000_000 // 1MB

// https://www.poplatek.fi/payments/jsonpos/transport
// JSON/RPC messages are framed with the following format (in the following byte-by-byte order):
// 8 bytes: ASCII lowercase hex-encoded length (LEN) of the actual JSON/RPC message (receiver MUST accept both uppercase and lowercase)
// 1 byte: a colon (":", 0x3a), not included in LEN
// LEN bytes: a JSON/RPC message, no leading or trailing whitespace
// 1 byte: a newline (0x0a), not included in LEN
final class JSONPosCodec: ByteToMessageDecoder, MessageToByteEncoder {
    typealias InboundIn = ByteBuffer
    typealias InboundOut = ByteBuffer
    typealias OutboundIn = ByteBuffer
    typealias OutboundOut = ByteBuffer
    
    private let newline = UInt8(ascii: "\n")
    private let colon = UInt8(ascii: ":")
    
    // inbound
    func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        guard buffer.readableBytes < maxPayload else {
            throw CodecError.requestTooLarge
        }
        guard buffer.readableBytes >= 10 else {
            return .needMoreData
        }
        
        let readableBytesView = buffer.readableBytesView
        // assuming we have the format <length>:<payload>\n
        let lengthView = readableBytesView.prefix(8) // contains <length>
        let fromColonView = readableBytesView.dropFirst(8) // contains :<payload>\n
        let payloadView = fromColonView.dropFirst() // contains <payload>\n
        let hex = String(decoding: lengthView, as: Unicode.UTF8.self)
        
        guard let payloadSize = Int(hex, radix: 16) else {
            throw CodecError.badFraming
        }
        guard self.colon == fromColonView.first! else {
            throw CodecError.badFraming
        }
        guard payloadView.count >= payloadSize + 1, self.newline == payloadView.last else {
            return .needMoreData
        }
        
        // slice the buffer
        assert(payloadView.startIndex == readableBytesView.startIndex + 9)
        let slice = buffer.getSlice(at: payloadView.startIndex, length: payloadSize)!
        buffer.moveReaderIndex(to: payloadSize + 10)
        // call next handler
        context.fireChannelRead(wrapInboundOut(slice))
        return .continue
    }
    
    func decodeLast(context: ChannelHandlerContext, buffer: inout ByteBuffer, seenEOF: Bool) throws -> DecodingState {
        while try self.decode(context: context, buffer: &buffer) == .continue {}
        if buffer.readableBytes > buffer.readerIndex {
            throw CodecError.badFraming
        }
        return .needMoreData
    }
    
    // outbound
    func encode(data: OutboundIn, out: inout ByteBuffer) throws {
        var payload = data
        // length
        out.writeString(String(payload.readableBytes, radix: 16).leftPadding(toLength: 8, withPad: "0"))
        // colon
        out.writeBytes([colon])
        // payload
        out.writeBuffer(&payload)
        // newline
        out.writeBytes([newline])
    }
}
