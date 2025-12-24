import Foundation

extension JSONRPCRequest {
    public enum Params: Codable, Sendable {
        case
            help(HelpRPC.Params),
            status,
            stop,
            startP2P(StartP2PRPC.Params),
            stopP2P,
            connect(ConnectRPC.Params),
            disconnectPeer(DisconnectPeerRPC.Params),
            getBlockHash(GetBlockHashRPC.Params),
            getBlock(GetBlockRPC.Params),
            getHeader(GetHeaderRPC.Params),
            generateToAddress(GenerateToAddressRPC.Params),
            getBlockchainInfo,
            getChainTips,
            getMempool,
            getPeerInfo,
            getTransaction(GetTransactionRPC.Params),
            sendTransaction(SendTransactionRPC.Params),
            reindex,
            reindexStatus,
            reindexStop
    }
}

extension JSONRPCRequest.Params {

    public init(from decoder: any Decoder) throws {
        guard let method = decoder.userInfo[.method] as? String else {
            throw DecodingError.typeMismatch(Self.self, .init(codingPath: decoder.codingPath, debugDescription: ""))
        }
        try self.init(from: decoder, method: method)
    }

    public init(from decoder: any Decoder, method: String) throws {
        self = switch method {
        case HelpRPC.method: .help(try .init(from: decoder))
        case StatusRPC.method: .status
        case StopRPC.method: .stop
        case StartP2PRPC.method: .startP2P(try .init(from: decoder))
        case StopP2PRPC.method: .stopP2P
        case ConnectRPC.method: .connect(try .init(from: decoder))
        case DisconnectPeerRPC.method: .disconnectPeer(try .init(from: decoder))
        case GetBlockHashRPC.method: .getBlockHash(try .init(from: decoder))
        case GetBlockRPC.method: .getBlock(try .init(from: decoder))
        case GetHeaderRPC.method: .getHeader(try .init(from: decoder))
        case GenerateToAddressRPC.method: .generateToAddress(try .init(from: decoder))
        case GetBlockchainInfoRPC.method: .getBlockchainInfo
        case GetChainTipsRPC.method: .getChainTips
        case GetMempoolRPC.method: .getMempool
        case GetPeerInfoRPC.method: .getPeerInfo
        case GetTransactionRPC.method: .getTransaction(try .init(from: decoder))
        case SendTransactionRPC.method: .sendTransaction(try .init(from: decoder))
        case ReindexRPC.method: .reindex
        case ReindexStatusRPC.method: .reindexStatus
        case ReindexStopRPC.method: .reindexStop
        default: throw DecodingError.typeMismatch(Self.self, .init(codingPath: decoder.codingPath, debugDescription: ""))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .help(let params): try params.encode(to: encoder)
        case .status: try container.encodeNil()
        case .stop: try container.encodeNil()
        case .startP2P(let params): try params.encode(to: encoder)
        case .stopP2P: try container.encodeNil()
        case .connect(let params): try params.encode(to: encoder)
        case .disconnectPeer(let params): try params.encode(to: encoder)
        case .getBlockHash(let params): try params.encode(to: encoder)
        case .getBlock(let params): try params.encode(to: encoder)
        case .getHeader(let params): try params.encode(to: encoder)
        case .generateToAddress(let params): try params.encode(to: encoder)
        case .getBlockchainInfo: try container.encodeNil()
        case .getChainTips: try container.encodeNil()
        case .getMempool: try container.encodeNil()
        case .getPeerInfo: try container.encodeNil()
        case .getTransaction(let params): try params.encode(to: encoder)
        case .sendTransaction(let params): try params.encode(to: encoder)
        case .reindex: try container.encodeNil()
        case .reindexStatus: try container.encodeNil()
        case .reindexStop: try container.encodeNil()
        }
    }

    public var method: String {
        switch self {
        case .help(_): HelpRPC.method
        case .status: StatusRPC.method
        case .stop: StopRPC.method
        case .startP2P(_): StartP2PRPC.method
        case .stopP2P: StopP2PRPC.method
        case .connect(_): ConnectRPC.method
        case .disconnectPeer(_): DisconnectPeerRPC.method
        case .getBlockHash(_): GetBlockHashRPC.method
        case .getBlock(_): GetBlockRPC.method
        case .getHeader(_): GetHeaderRPC.method
        case .generateToAddress(_): GenerateToAddressRPC.method
        case .getBlockchainInfo: GetBlockchainInfoRPC.method
        case .getChainTips: GetChainTipsRPC.method
        case .getMempool: GetMempoolRPC.method
        case .getPeerInfo: GetPeerInfoRPC.method
        case .getTransaction(_): GetTransactionRPC.method
        case .sendTransaction(_): SendTransactionRPC.method
        case .reindex: ReindexRPC.method
        case .reindexStatus: ReindexStatusRPC.method
        case .reindexStop: ReindexStopRPC.method
        }
    }
}
