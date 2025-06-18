extension Transaction {

    public struct GenesisParams: Sendable {

        public init(timestampMessage: String, reward: Amount, outputScript: Script) {
            self.timestampMessage = timestampMessage
            self.reward = reward
            self.outputScript = outputScript
        }

        public let timestampMessage: String
        public let reward: Amount
        public let outputScript: Script
    }
}
