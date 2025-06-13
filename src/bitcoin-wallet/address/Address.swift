import BitcoinBase

/// Type-erased bitcoin address. Use when needing to decode and generate outputs but the type of address being decoded is not known beforehand
public enum Address: AddressProtocol {

    case legacy(LegacyAddress), segwit(SegwitAddress), taproot(TaprootAddress)

    public init?(_ address: String) {
        if let a = LegacyAddress(address) { self = .legacy(a) }
        else if let a = SegwitAddress(address) { self = .segwit(a) }
        else if let a = TaprootAddress(address) { self = .taproot(a) }
        else { return nil }
    }

    public var script: Script {
        let address: any AddressProtocol = switch self {
        case .legacy(let a): a
        case .segwit(let a): a
        case .taproot(let a): a
        }
        return address.script
    }

    public var description: String {
        let address: any AddressProtocol = switch self {
        case .legacy(let a): a
        case .segwit(let a): a
        case .taproot(let a): a
        }
        return address.description
    }

    /// Whether the address is compatible with a chain identifier from `BitcoinBlockchain/ConsensusParams`.
    public func isCompatibleWithChain(_ chain: String) -> Bool {
        let network: WalletNetwork
        switch self {
        case .legacy(let a):
            return a.isMainnet && chain == "mainnet" || (!a.isMainnet && chain != "mainnet")
        case .segwit(let a):
            network = a.network
        case .taproot(let a):
            network = a.network
        }
        // TODO: What about signet? Should all non-identified chains be linked to regtest network type? Should we add a network type param to ConsensusParams on top of the chain ID?
        return network == .main && chain == "mainnet" ||
               (network == .test && (chain == "testnet" || chain == "testnet4")) ||
               (network == .regtest && !["mainnet", "testnet", "testnet4"].contains(chain))
    }
}
