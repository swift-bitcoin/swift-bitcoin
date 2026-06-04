import ArgumentParser

extension NodeConfig {

    enum ConfigError: Error {
        case conflictingArguments(String, String)
    }
}

extension ValidationError {
    init(_ error: NodeConfig.ConfigError) {
        self = switch error {
        case let .conflictingArguments(arg1, arg2):
            ValidationError("Conflicting arguments \"\(arg1)\" vs \"\(arg2)\"")
        }
    }
}
