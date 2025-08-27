extension BlockchainService {

    public struct Config: Sendable {

        /// Where to read and store data from.
        ///
        /// Data includes databases containing indices as well as block files which include undo information.
        public enum DataLocation: Sendable {

            /// In-memory only storage. No persistence.
            case inMemory

            /// Default data directory.
            case defaultPath

            /// Custom data directory.
            case custom(path: String)
        }

        public init(dataLocation: Config.DataLocation = .inMemory) {
            self.dataLocation = dataLocation
        }

        let dataLocation: DataLocation

        /// Maximum number of attempts to hit the difficulty target when generating blocks.
        public static let defaultMaxTries = 1_000_000
    }
}
