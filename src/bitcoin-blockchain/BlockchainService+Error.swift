/// Error types extension.
extension BlockchainService {

    /// Error during initialization of the blockchain service.
    ///
    /// Usually represents a failure to initialize one of the subsystems like disk block storage or an index database.
    public enum InitError: Swift.Error {

        /// Problem creating or reading the data directory.
        case dataDirIssue
    }

    /// An error during a blockchain operation.
    public enum Error: Swift.Error {

        /// A transaction in the block could not be validated.
        case invalidTransactionInBlock(TransactionValidationError)

        case unsupportedBlockVersion, orphanHeader, invalidDifficultyTarget, insuficientProofOfWork, headerTooOld, headerTooNew, headerPartOfInvalidChain, missingCoinbaseTransaction, coinbaseTransactionOverspends, wrongMerkleRoot, blockAlreadyExists, futureLockTime

        case dataDirIssue, blockFileIssue, receivedCancellation

        /// Block's timestamp is too early on diff adjustment block.
        case timewarpAttack
    }
}
