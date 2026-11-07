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
        self =
            switch error {
            case .conflictingArguments(let arg1, let arg2):
                ValidationError("Conflicting arguments \"\(arg1)\" vs \"\(arg2)\"")
            case .invalidHexadecimalString(let string):
                ValidationError("Invalid hexadecimal string: \(string)")
            case .invalidScript(let string):
                ValidationError("Invalid script: \(string)")
            }
    }
}
