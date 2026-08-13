import ArgumentParser
import BitcoinBlockchain
import struct SystemPackage.FilePath
import Foundation

struct ChainInfo: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "info",
        abstract: ""
    )

    @OptionGroup var parent: Chain

    mutating func run() async throws {
        let network = try parent.resolvedNetwork
        let blockchain = try await BlockchainService(params: network.params, config: .init(dataLocation: .defaultPath), logger: .init(label: ""))
        print("""
        Headers: \(await blockchain.headers)
        Blocks: \(await blockchain.height)
        """)
    }
}
