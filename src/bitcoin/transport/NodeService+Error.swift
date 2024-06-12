/// Defines the `Error` inner enum.
extension NodeService {

    /// An error while establishing a connection with a peer or processing an incoming message.
    public enum Error: Swift.Error, Sendable {
        case versionMissing, connectionToSelf, unsupportedVersion, unsupportedServices, invalidPayload, missingWTXIDRelayPreference, requestedWTXIDRelayAfterVerack, missingV2AddrPreference, requestedV2AddrAfterVerack, pingPongMismatch, unsupportedCompactBlocksVersion, badHeader
    }
}
