import Foundation
import BitcoinP2P
import NIO

internal final class MessageCoder: ByteToMessageDecoder, MessageToByteEncoder {
    public typealias InboundIn = ByteBuffer
    public typealias InboundOut = BitcoinMessage
    public typealias OutboundIn = BitcoinMessage
    public typealias OutboundOut = ByteBuffer

    public func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {

        guard buffer.readableBytes >= BitcoinMessage.payloadSizeEndIndex else {
            return .needMoreData
        }

        let peek = buffer.readableBytesView[BitcoinMessage.payloadSizeStartIndex...]
        let payloadLength = Int(peek.withUnsafeBytes {
            $0.load(as: UInt32.self)
        })

        let messageLength = BitcoinMessage.baseSize + payloadLength
        guard let slice = buffer.readSlice(length: messageLength) else {
            return .needMoreData
        }

        let messageData = Data(slice.readableBytesView)
        guard let message = BitcoinMessage(messageData) else {
            print("Malformed message")
            print(messageData.hex)
            // TODO: Throw corresponding errors.
            return .continue

        }
        guard message.isChecksumOk else {
            print("Wrong message checksum")
            debugPrint(message)
            print(message.data.hex)
            fatalError() // TODO: Throw corresponding errors.
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
