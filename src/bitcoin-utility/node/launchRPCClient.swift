import Foundation
import NIOCore
import NIOPosix
import JSONRPC

public func launchRPCClient(port: Int, method: String, params: [String]) async throws {
    let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)

    let clientChannel = try await ClientBootstrap(
        group: eventLoopGroup
    )
    .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
    .connect(
        host: "127.0.0.1",
        port: port
    ) { channel in
        channel.pipeline.addHandlers([
            IdleStateHandler(readTimeout: TimeAmount.seconds(5)),
            HalfCloseOnTimeout(),
            ByteToMessageHandler(NewlineEncoder()),
            MessageToByteHandler(NewlineEncoder()),
            CodableCodec<JSONResponse, JSONRequest>()
        ])
        .eventLoop.makeCompletedFuture {
            try NIOAsyncChannel<JSONResponse, JSONRequest>(
                wrappingChannelSynchronously: channel
            )
        }
    }

    try await clientChannel.executeThenClose {
        let params = if method == "generate-to" {
            JSONObject(RPCObject(params))
        } else {
            JSONObject(RPCObject(params.compactMap { Int($0) }))
        }
        let request = JSONRequest(id: NSUUID().uuidString, method: method,
            params: params)
        try await $1.write(request)
        try await handleRPC($0, $1)
    }
}

private func handleRPC(_ inbound: NIOAsyncChannelInboundStream<JSONResponse>, _ outbound: NIOAsyncChannelOutboundWriter<JSONRequest>) async throws -> () {

    for try await response in inbound {
        if let result = response.result {
            if case .string(let stringResult) = result {
                print(stringResult)
            } else {
                print(result)
            }
        } else if let error = response.error {
            print(error)
        } else {
            print("Received empty result.")
        }
    }
}
