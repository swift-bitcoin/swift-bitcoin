import ServiceLifecycle
import NIOCore
import NIOPosix
import BitcoinP2P

public func launchNode(port: Int) async throws {
    let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
    let p2pService = P2PService(eventLoopGroup: eventLoopGroup)
    let p2pClientService0 = P2PClientService(eventLoopGroup: eventLoopGroup)
    let rpcService = RPCService(port: port, eventLoopGroup: eventLoopGroup, p2pService: p2pService, p2pClientService0: p2pClientService0)
    let serviceGroup = ServiceGroup(configuration: .init(
        services: [p2pService, p2pClientService0, rpcService],
        gracefulShutdownSignals: [.sigint, .sigterm],
        cancellationSignals: [.sigquit],
        logger: .init(label: "mainServiceGroup")
    ))
    await rpcService.setServiceGroup(serviceGroup)
    try await serviceGroup.run()
}
