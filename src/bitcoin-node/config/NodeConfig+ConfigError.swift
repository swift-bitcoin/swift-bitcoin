import ArgumentParser

extension NodeConfig {

    enum ConfigError: Error {
        case invalidHexadecimalString(String)
        case conflictingArguments(String, String)
        case invalidScript(String)
    }
}

extension ValidationError {
    init(_ error: NodeConfig.ConfigError) {
        self = switch error {
        case let .conflictingArguments(arg1, arg2):
            ValidationError("Conflicting arguments \"\(arg1)\" vs \"\(arg2)\"")
        case let .invalidHexadecimalString(string):
            ValidationError("Invalid hexadecimal string: \(string)")
        case let .invalidScript(string):
            ValidationError("Invalid script: \(string)")
        }
    }
}
