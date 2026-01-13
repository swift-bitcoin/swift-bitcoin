import ArgumentParser
import JSONRPC
import BitcoinBlockchain
import struct SystemPackage.FilePath
import Foundation

struct ChainTips: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "tips",
        abstract: ""
    )

    @OptionGroup var parent: Chain

    mutating func run() async throws {
        let params: ConsensusParams = switch parent.network {
        case .mainnet: .mainnet
        case .testnet: .testnet
        case .regtest: .regtest
        }
        let blockchain = try await BlockchainService(params: params, config: .init(dataLocation: .defaultPath), logger: .init(label: "tips"))
        let tips = await blockchain.chainTips

        let printableTips = tips.map {
            let status: GetChainTipsRPC.Tip.Status = switch $0.status {
            case .active: .active
            case .stale: .validFork
            case .merkle: .validHeaders
            case .header: .headersOnly
            case .invalid: .invalid
            }
            return GetChainTipsRPC.Tip(height: $0.height, hash: $0.tip.reversed().hex, branchlen: $0.branchLength, status: status)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        let data = try encoder.encode(printableTips)
        print(String(data: data, encoding: .utf8)!)
    }
}
