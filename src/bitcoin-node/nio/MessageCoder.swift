import BitcoinTransport
import NIOCore
import NIOFoundationCompat

/// Bitcoin Message encoder/decoder.
struct MessageCoder: ByteToMessageDecoder, MessageToByteEncoder {

    typealias InboundIn = ByteBuffer
    typealias InboundOut = Message
    typealias OutboundIn = Message
    typealias OutboundOut = ByteBuffer

    func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {

        guard buffer.readableBytes >= Message.payloadSizeEndIndex else {
            return .needMoreData
        }

        let peek = buffer.readableBytesView.dropFirst(Message.payloadSizeStartIndex)
        let payloadLength = Int(peek.withUnsafeBytes {
            $0.loadUnaligned(as: UInt32.self)
        })

        let messageLength = Message.baseSize + payloadLength
        guard let messageData = buffer.readData(length: messageLength) else {
            return .needMoreData
        }

        guard let message = Message(messageData) else {
            print("Malformed message")
            // TODO: Throw corresponding errors.
            return .continue

        }
        guard message.isChecksumOk else {
            fatalError() // TODO: Throw corresponding errors.
            // context.fireErrorCaught(T##error: Error##Error)
        }

        // call next handler
        context.fireChannelRead(wrapInboundOut(message))
        return .continue
    }

    // outbound
    func encode(data message: OutboundIn, out: inout ByteBuffer) throws {
        out.writeBytes(message.data)
    }
}
