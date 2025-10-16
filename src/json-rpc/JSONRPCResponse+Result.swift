import Foundation

extension JSONRPCResponse {
    public enum Result: Codable, Sendable {
        case
            help(HelpRPC.Result),
            status(StatusRPC.Result),
            stop,
            startP2P(StartP2PRPC.Result),
            stopP2P,
            connect(ConnectRPC.Result),
            disconnectPeer(DisconnectPeerRPC.Result),
            getBlockHash(GetBlockHashRPC.Result),
            getBlock(GetBlockRPC.Result),
            generateToAddress(GenerateToAddressRPC.Result),
            getBlockchainInfo(GetBlockchainInfoRPC.Result),
            getChainTips(GetChainTipsRPC.Result),
            getMempool(GetMempoolRPC.Result),
            getPeerInfo(GetPeerInfoRPC.Result),
            getTransaction(GetTransactionRPC.Result),
            sendTransaction(SendTransactionRPC.Result)
    }
}

extension JSONRPCResponse.Result {

    public init(from decoder: any Decoder) throws {
        guard let method = decoder.userInfo[.method] as? String else {
            throw DecodingError.typeMismatch(Self.self, .init(codingPath: decoder.codingPath, debugDescription: ""))
        }
        self = switch method {
        case HelpRPC.method: .help(try .init(from: decoder))
        case StatusRPC.method: .status(try .init(from: decoder))
        case StopRPC.method: .stop
        case StartP2PRPC.method: .startP2P(try .init(from: decoder))
        case StopP2PRPC.method: .stopP2P
        case ConnectRPC.method: .connect(try .init(from: decoder))
        case DisconnectPeerRPC.method: .disconnectPeer(try .init(from: decoder))
        case GetBlockHashRPC.method: .getBlockHash(try .init(from: decoder))
        case GetBlockRPC.method: .getBlock(try .init(from: decoder))
        case GenerateToAddressRPC.method: .generateToAddress(try .init(from: decoder))
        case GetBlockchainInfoRPC.method: .getBlockchainInfo(try .init(from: decoder))
        case GetChainTipsRPC.method: .getChainTips(try .init(from: decoder))
        case GetMempoolRPC.method: .getMempool(try .init(from: decoder))
        case GetPeerInfoRPC.method: .getPeerInfo(try .init(from: decoder))
        case GetTransactionRPC.method: .getTransaction(try .init(from: decoder))
        case SendTransactionRPC.method: .sendTransaction(try .init(from: decoder))
        default: throw DecodingError.typeMismatch(Self.self, .init(codingPath: decoder.codingPath, debugDescription: ""))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .help(let result): try result.encode(to: encoder)
        case .status(let result): try result.encode(to: encoder)
        case .stop: try container.encodeNil()
        case .startP2P(let result): try result.encode(to: encoder)
        case .stopP2P: try container.encodeNil()
        case .connect(let result): try result.encode(to: encoder)
        case .disconnectPeer(let result): try result.encode(to: encoder)
        case .getBlockHash(let result): try result.encode(to: encoder)
        case .getBlock(let result): try result.encode(to: encoder)
        case .generateToAddress(let result): try result.encode(to: encoder)
        case .getBlockchainInfo(let result): try result.encode(to: encoder)
        case .getChainTips(let result): try result.encode(to: encoder)
        case .getMempool(let result): try result.encode(to: encoder)
        case .getPeerInfo(let result): try result.encode(to: encoder)
        case .getTransaction(let result): try result.encode(to: encoder)
        case .sendTransaction(let result): try result.encode(to: encoder)
        }
    }
}
