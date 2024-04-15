import Foundation
import Bitcoin
import NIO

final class MessageCoder: ByteToMessageDecoder, MessageToByteEncoder {
    typealias InboundIn = ByteBuffer
    typealias InboundOut = BitcoinMessage
    typealias OutboundIn = BitcoinMessage
    typealias OutboundOut = ByteBuffer

    func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {

        guard buffer.readableBytes >= BitcoinMessage.payloadSizeEndIndex else {
            return .needMoreData
        }

        let peekFrom = buffer.readableBytesView.startIndex.advanced(by: BitcoinMessage.payloadSizeStartIndex)
        let peek = buffer.readableBytesView[peekFrom...]
        let payloadLength = Int(peek.withUnsafeBytes {
            $0.loadUnaligned(as: UInt32.self)
        })

        let messageLength = BitcoinMessage.baseSize + payloadLength
        guard let messageData = buffer.readData(length: messageLength) else {
            return .needMoreData
        }

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
    func encode(data message: OutboundIn, out: inout ByteBuffer) throws {
        out.writeBytes(message.data)
    }
}
