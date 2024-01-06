import NIOPosix
import ServiceLifecycle
import NIOCore

public func launchNode(port: Int) async throws {
    let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
    let rpcService = RPCService(port: port, eventLoopGroup: eventLoopGroup)
    let serviceGroup = ServiceGroup(configuration: .init(
        services: [rpcService],
        gracefulShutdownSignals: [.sigint,],
        cancellationSignals: [.sigterm, .sigquit],
        logger: .init(label: "mainServiceGroup")
    ))
    await rpcService.setServiceGroup(serviceGroup)
    try await serviceGroup.run()
}
