import ArgumentParser

extension NodeConfig {

    enum ParseError: Error {
        case locateDirectory(String)
        case readDirectory(String)
        case missingFile(String)
        case invalidExtension
        case notDirectory(String)
        case notFileOrDirectory(String)
        case maximumSizeExceeded(size: Int, max: Int)
        case unknownOpenReadIssue
        case decodingError
        case swiftConfigError
        case missingInternalResource
        case internalResourceUnavailable
        case swiftScriptFailure
        case unableToCreateDirectory
    }
}

extension ValidationError {
    init(_ error: NodeConfig.ParseError) {
        self = switch error {
        case .locateDirectory(let location):
            ValidationError("Could not locate directory/file at \"\(location)\"")
        case .readDirectory(let location):
            ValidationError("Issue retrieving directory/file information at \"\(location)\"")
        case .missingFile(let location):
            ValidationError("Could not find either config.swift or config.json in \"\(location)\".")
        case .invalidExtension:
            ValidationError("Only \".swift\" or \".json\" file extensions are accepted.")
        case .notDirectory(let location):
            ValidationError("Found regular file instead of directory at \"\(location)\".")
        case .notFileOrDirectory(let location):
            ValidationError("Could not find directory or regular file at \"\(location)\".")
        case let .maximumSizeExceeded(size, max):
            ValidationError("Maximum file size allowes is \(max) bytes (current file is \(size) bytes.")
        case .unknownOpenReadIssue:
            ValidationError("Unable to open/read file.")
        case .decodingError:
            ValidationError("Could not decode JSON configuration.")
        case .swiftConfigError:
            ValidationError("Could not read Swift configuration.")
        case .missingInternalResource:
            ValidationError("Error finding internal resource file \"NodeConfig.txt\".")
        case .internalResourceUnavailable:
            ValidationError("Unable to read internal resource file contents.")
        case .swiftScriptFailure:
            ValidationError("Issue while converting Swift configuration.")
        case .unableToCreateDirectory:
            ValidationError("Unable to create default directory.")
        }
    }
}
