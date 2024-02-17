import Bitcoin
import NIO

func handleIO(bitcoinService: BitcoinService, isClient: Bool = false, _ inbound: NIOAsyncChannelInboundStream<Message>, _ outbound: NIOAsyncChannelOutboundWriter<Message>) async throws -> () {

    var peerContext = PeerContext(isClient: isClient)

    if isClient {
        let message = getFirstMessage(context: &peerContext)
        try await outbound.write(message)
    }

    let blocks = await bitcoinService.blocks
    Task {
        for await block in blocks.cancelOnGracefulShutdown() {
            print("New block (might send to peer):\n\t\(block.hash.hex)]")
        }
    }

    for try await message in inbound.cancelOnGracefulShutdown() {
        if let response = try processMessage(message, context: &peerContext) {
            try await outbound.write(response)
        }
    }

    await bitcoinService.unsubscribe(blocks)
}
