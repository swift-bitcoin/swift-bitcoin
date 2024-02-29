import Bitcoin
import ServiceLifecycle
import NIO

func launchNode(host: String, port: Int) async throws {

    let bitcoinService = BitcoinService()
    let bitcoinNode = BitcoinNode(bitcoinService: bitcoinService)

    let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)

    let p2pClientServices = (0 ..< 3).map { _ in
        P2PClientService(eventLoopGroup: eventLoopGroup, bitcoinNode: bitcoinNode)
    }

    let p2pService = P2PService(eventLoopGroup: eventLoopGroup, bitcoinNode: bitcoinNode)

    let rpcService = RPCService(host: host, port: port, eventLoopGroup: eventLoopGroup, bitcoinNode: bitcoinNode, bitcoinService: bitcoinService, p2pService: p2pService, p2pClientServices: p2pClientServices)
    let serviceGroup = ServiceGroup(configuration: .init(
        services: [bitcoinNode] + p2pClientServices + [p2pService, rpcService],
        gracefulShutdownSignals: [.sigint, .sigterm],
        cancellationSignals: [.sigquit],
        logger: .init(label: "mainServiceGroup")
    ))
    await rpcService.setServiceGroup(serviceGroup)
    try await serviceGroup.run()

    await bitcoinService.shutdown()
}
