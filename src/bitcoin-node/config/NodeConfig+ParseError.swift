import ArgumentParser

extension NodeConfig {

    enum ParseError: Error {
        case locateFolder(String)
        case readFolder(String)
        case missingFile(String)
        case invalidExtension
        case notFileOrFolder(String)
        case maximumSizeExceeded(size: Int, max: Int)
        case unknownOpenReadIssue
        case decodingError
        case swiftConfigError
        case missingInternalResource
        case internalResourceUnavailable
        case swiftScriptFailure
        case unableToCreateFolder
    }
}

extension ValidationError {
    init(_ error: NodeConfig.ParseError) {
        self = switch error {
        case .locateFolder(let location):
            ValidationError("Could not locate folder/file at \"\(location)\"")
        case .readFolder(let location):
            ValidationError("Issue retrieving folder/file information at \"\(location)\"")
        case .missingFile(let location):
            ValidationError("Could not find either config.swift or config.json in \"\(location)\".")
        case .invalidExtension:
            ValidationError("Only \".swift\" or \".json\" file extensions are accepted.")
        case .notFileOrFolder(let location):
            ValidationError("Could not find folder or regular file at \"\(location)\".")
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
        case .unableToCreateFolder:
            ValidationError("Unable to create default folder.")
        }
    }
}
