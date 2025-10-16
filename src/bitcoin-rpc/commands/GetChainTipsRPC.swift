import Foundation
import JSONRPC
import BitcoinBlockchain

extension GetChainTipsRPC {

    public func run(blockchain: BlockchainService) async -> Result {
        let tips = await blockchain.chainTips

        return tips.map {
            let status: Tip.Status = switch $0.status {
            case .active: .active
            case .stale: .validFork
            case .merkle: .validHeaders
            case .header: .headersOnly
            case .invalid: .invalid
            }
            return Tip(height: $0.height, hash: $0.tip.reversed().hex, branchlen: $0.branchLength, status: status)
        }
    }
}
