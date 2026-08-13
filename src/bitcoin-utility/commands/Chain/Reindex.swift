import ArgumentParser
import BitcoinBlockchain
import struct SystemPackage.FilePath
import Foundation
import Logging

struct Reindex: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: ""
    )

    @OptionGroup var parent: Chain

    @Option var decodeOnly = false
    @Option var headersOnly = false

    mutating func run() async throws {
        var logger = Logger(label: "reindex")
        logger.logLevel = .info
        let network = try parent.resolvedNetwork
        let blockchain = try await BlockchainService(params: network.params, config: .init(dataLocation: .defaultPath), logger: logger)
        await blockchain.reindex(decodeOnly: decodeOnly, headersOnly: headersOnly)
    }
}
