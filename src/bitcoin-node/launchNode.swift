import Bitcoin
import BitcoinP2P
import ServiceLifecycle
import NIO

public func launchNode(host: String, port: Int) async throws {

    let bitcoinService = BitcoinService()

    let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
    let p2pService = P2PService(eventLoopGroup: eventLoopGroup, bitcoinService: bitcoinService)

    let p2pClientServices = (0 ..< 3).map { _ in
        P2PClientService(eventLoopGroup: eventLoopGroup, bitcoinService: bitcoinService)
    }

    Task {
        for await block in await bitcoinService.blocks {
            print("New block found:\n\t\(block.hash.hex)")
        }
    }

    let rpcService = RPCService(host: host, port: port, eventLoopGroup: eventLoopGroup, bitcoinService: bitcoinService, p2pService: p2pService, p2pClientServices: p2pClientServices)
    let serviceGroup = ServiceGroup(configuration: .init(
        services: [p2pService] + p2pClientServices + [rpcService],
        gracefulShutdownSignals: [.sigint, .sigterm],
        cancellationSignals: [.sigquit],
        logger: .init(label: "mainServiceGroup")
    ))
    await rpcService.setServiceGroup(serviceGroup)
    try await serviceGroup.run()

    await bitcoinService.shutdown()
}
