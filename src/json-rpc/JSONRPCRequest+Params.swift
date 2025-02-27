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
            generateToAddress(GenerateToAddressRPC.Params),
            getBlockchainInfo,
            getMempool,
            getPeerInfo,
            getTransaction(GetTransactionRPC.Params),
            sendTransaction(SendTransactionRPC.Params)
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
        case GenerateToAddressRPC.method: .generateToAddress(try .init(from: decoder))
        case GetBlockchainInfoRPC.method: .getBlockchainInfo
        case GetMempoolRPC.method: .getMempool
        case GetPeerInfoRPC.method: .getPeerInfo
        case GetTransactionRPC.method: .getTransaction(try .init(from: decoder))
        case SendTransactionRPC.method: .sendTransaction(try .init(from: decoder))
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
        case .generateToAddress(let params): try params.encode(to: encoder)
        case .getBlockchainInfo: try container.encodeNil()
        case .getMempool: try container.encodeNil()
        case .getPeerInfo: try container.encodeNil()
        case .getTransaction(let params): try params.encode(to: encoder)
        case .sendTransaction(let params): try params.encode(to: encoder)
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
        case .generateToAddress(_): GetBlockRPC.method
        case .getBlockchainInfo: GetBlockchainInfoRPC.method
        case .getMempool: GetMempoolRPC.method
        case .getPeerInfo: GetPeerInfoRPC.method
        case .getTransaction(_): GetTransactionRPC.method
        case .sendTransaction(_): SendTransactionRPC.method
        }
    }
}
