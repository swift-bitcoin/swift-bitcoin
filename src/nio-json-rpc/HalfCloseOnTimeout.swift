public import enum NIOCore.ChannelEvent // Internal
public import class NIOCore.ChannelHandlerContext
public import protocol NIOCore.ChannelInboundHandler
public import class NIOCore.IdleStateHandler // Internal

public final class HalfCloseOnTimeout: ChannelInboundHandler, Sendable {
    public typealias InboundIn = Any

    public init() {}

    public func userInboundEventTriggered(context: ChannelHandlerContext, event: Any) {
        if event is IdleStateHandler.IdleStateEvent {
            // this will trigger ByteToMessageDecoder::decodeLast which is required to
            // recognize partial frames
            context.fireUserInboundEventTriggered(ChannelEvent.inputClosed)
        }
        context.fireUserInboundEventTriggered(event)
    }
}
