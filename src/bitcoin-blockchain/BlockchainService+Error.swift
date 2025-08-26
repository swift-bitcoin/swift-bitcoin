extension BlockchainService {

    public enum Error: Swift.Error {
        case invalidTransactionInBlock(TransactionValidationError)
        case unsupportedBlockVersion, orphanHeader, invalidDifficultyTarget, insuficientProofOfWork, headerTooOld, headerTooNew, headerPartOfInvalidChain, missingCoinbaseTransaction, coinbaseTransactionOverspends, wrongMerkleRoot, blockAlreadyExists

        case dataDirIssue, blockFileIssue, receivedCancellation

        /// Block's timestamp is too early on diff adjustment block.
        case timewarpAttack
    }
}
