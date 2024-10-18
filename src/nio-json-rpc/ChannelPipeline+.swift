import NIOCore
import JSONRPC

extension ChannelPipeline {
    func addTimeoutHandlers(_ timeout: TimeAmount) -> EventLoopFuture<Void> {
        return self.addHandlers([IdleStateHandler(readTimeout: timeout), HalfCloseOnTimeout()])
    }
    
    func addFramingHandlers(framing: Framing) -> EventLoopFuture<Void> {
        switch framing {
        case .jsonpos:
            let framingHandler = JSONPosCodec()
            return self.addHandlers([ByteToMessageHandler(framingHandler),
                                     MessageToByteHandler(framingHandler)])
        case .brute:
            let framingHandler = BruteForceCodec<JSONResponse>()
            return self.addHandlers([ByteToMessageHandler(framingHandler),
                                     MessageToByteHandler(framingHandler)])
        case .default:
            let framingHandler = NewlineEncoder()
            return self.addHandlers([ByteToMessageHandler(framingHandler),
                                     MessageToByteHandler(framingHandler)])
        }
    }
}
