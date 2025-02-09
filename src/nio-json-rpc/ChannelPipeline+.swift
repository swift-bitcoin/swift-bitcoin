import NIOCore
import JSONRPC

extension ChannelPipeline {

    /// Needs to be called within the event loop as part of async initialization.
    func addTimeoutHandlers(_ timeout: TimeAmount) throws {
        try syncOperations.addHandlers([IdleStateHandler(readTimeout: timeout), HalfCloseOnTimeout()])
    }

    /// Needs to be called within the event loop as part of async initialization.
    func addFramingHandlers(framing: Framing) throws {
        switch framing {
        case .jsonpos:
            let framingHandler = JSONPosCodec()
            return try syncOperations.addHandlers([ByteToMessageHandler(framingHandler),
                                     MessageToByteHandler(framingHandler)])
        case .brute:
            let framingHandler = BruteForceCodec<JSONResponse>()
            return try syncOperations.addHandlers([ByteToMessageHandler(framingHandler),
                                     MessageToByteHandler(framingHandler)])
        case .default:
            let framingHandler = NewlineEncoder()
            return try syncOperations.addHandlers([ByteToMessageHandler(framingHandler),
                                     MessageToByteHandler(framingHandler)])
        }
    }
}
