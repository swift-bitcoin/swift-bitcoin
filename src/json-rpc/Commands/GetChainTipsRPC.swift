/// Return information about all known tips in the block tree, including the main chain as well as orphaned branches.
public struct GetChainTipsRPC: RPCCommand, Sendable {

    public typealias Params = Never

    public typealias Result = [Tip]

    public struct Tip: Codable, Sendable {

        public init(height: Int, hash: String, branchlen: Int, status: GetChainTipsRPC.Tip.Status) {
            self.height = height
            self.hash = hash
            self.branchlen = branchlen
            self.status = status
        }

        public enum Status: String, Codable, Sendable {

            /// This branch contains at least one invalid block
            case invalid

            /// Not all blocks for this branch are available, but the headers are valid
            case headersOnly = "headers-only"

            /// All blocks are available for this branch, but they were never fully validated
            case validHeaders = "valid-headers"

            /// This branch is not part of the active chain, but is fully validated
            case validFork = "valid-fork"

            /// This is the tip of the active main chain, which is certainly valid
            case active
        }

        /// height of the chain tip
        public let height: Int

        /// block hash of the tip
        public let hash: String

        /// zero for main chain, otherwise length of branch connecting the tip to the main chain
        public let branchlen: Int

        /// status of the chain, "active" for the main chain
        public let status: Status
    }

    public init() {}

    public static let method = "get-chain-tips"
    public static let params = ""
    public static let description: String = "Return information about all known tips in the block tree, including the main chain as well as orphaned branches."
}
