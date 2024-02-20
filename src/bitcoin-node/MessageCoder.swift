import Foundation
import BitcoinP2P
import NIO

internal final class MessageCoder: ByteToMessageDecoder, MessageToByteEncoder {
    public typealias InboundIn = ByteBuffer
    public typealias InboundOut = Message
    public typealias OutboundIn = Message
    public typealias OutboundOut = ByteBuffer

    public func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {

        guard buffer.readableBytes >= Message.payloadSizeEndIndex else {
            return .needMoreData
        }

        let peek = buffer.readableBytesView[Message.payloadSizeStartIndex...]
        let payloadLength = Int(peek.withUnsafeBytes {
            $0.load(as: UInt32.self)
        })

        let messageLength = Message.baseSize + payloadLength
        guard let slice = buffer.readSlice(length: messageLength) else {
            return .needMoreData
        }

        let messageData = Data(slice.readableBytesView)
        guard let message = Message(messageData), message.isChecksumOk else {
            preconditionFailure() // TODO: Throw corresponding errors.
            // context.fireErrorCaught(T##error: Error##Error)
        }

        // call next handler
        context.fireChannelRead(wrapInboundOut(message))
        return .continue
    }

    // outbound
    public func encode(data message: OutboundIn, out: inout ByteBuffer) throws {
        out.writeBytes(message.data)
    }
}
