import Logging

extension Logger.Level {
    init(_ level: NodeConfig.LogLevel) {
        self.init(rawValue: level.rawValue)!
    }
}
