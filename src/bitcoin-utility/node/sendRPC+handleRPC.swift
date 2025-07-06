import Foundation
import NIOCore
import NIOPosix
import JSONRPC
import NIOJSONRPC

public func sendRPC(host: String, port: Int, request: JSONRPCRequest) async throws {
    let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)

    let clientChannel = try await ClientBootstrap(
        group: eventLoopGroup
    )
    .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
    .connect(
        host: host,
        port: port
    ) { channel in
        channel.eventLoop.makeCompletedFuture {
            try channel.pipeline.syncOperations.addHandlers([
                IdleStateHandler(readTimeout: TimeAmount.seconds(2)),
                HalfCloseOnTimeout(),
                MessageToByteHandler(NewlineEncoder()),
                MessageToByteHandler(RequestEncoder()),
                ByteToMessageHandler(NewlineEncoder()),
                ByteToMessageHandler(ResponseDecoder(method: request.method)),
            ])
            return try NIOAsyncChannel<JSONRPCResponse, JSONRPCRequest>(
                wrappingChannelSynchronously: channel
            )
        }
    }

    try await clientChannel.executeThenClose {
        try await $1.write(request)
        try await handleRPC($0, $1)
    }
}

private func handleRPC(_ inbound: NIOAsyncChannelInboundStream<JSONRPCResponse>, _ outbound: NIOAsyncChannelOutboundWriter<JSONRPCRequest>) async throws -> () {

    for try await response in inbound {
        if let result = response.result {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(result)
            print(String(data: data, encoding: .utf8)!)
        } else if let error = response.error {
            print(error)
        } else {
            print("Received empty result.")
        }
    }
}
