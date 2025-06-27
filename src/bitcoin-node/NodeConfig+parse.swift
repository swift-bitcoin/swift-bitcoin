import Foundation
import NIOCore
import _NIOFileSystem

extension NodeConfig {

    static let defaultLocation = FilePath(URL.homeDirectory.relativePath).appending(".swift-bitcoin").string

    static func parse(_ location: String, strict: Bool = false) async throws(ParseError) -> Self {

        // Check whether we are accessing the default location
        let isDefault = location == Self.defaultLocation
        if isDefault {
            print("Checking default location \"\(location)\"…")
        } else {
            print("Checking custom location \"\(location)\"…")
        }

        // Find the actual configuration file

        let fs = FileSystem.shared
        let directoryOrFilePath = FilePath(location)
        let directoryOrFileInfo: FileInfo?
        let filePath: FilePath
        let fileInfo: FileInfo

        // Do we already have a path to the configuration file or just its containing folder?
        do {
            directoryOrFileInfo = try await fs.info(forFileAt: directoryOrFilePath)
        } catch {
            throw .locateFolder(location)
        }
        guard let directoryOrFileInfo else {
            if isDefault && !strict {
                do {
                    print("Creating directory \(directoryOrFilePath)…")
                    try await fs.createDirectory(at: directoryOrFilePath, withIntermediateDirectories: false)
                    print("Created.")
                } catch {
                    throw .internalResourceUnavailable
                }
                return .default
            }
            throw .readFolder(location)
        }
        if directoryOrFileInfo.type == .directory {
            // We have a directory, let's find out if it contains a valid configuration file
            let swiftFilePath = directoryOrFilePath.appending("config.swift")
            let jsonFilePath = directoryOrFilePath.appending("config.json")
            if let info = await getInfo(swiftFilePath), info.type == .regular {
                // We have a Swift configuration file
                // print("Found \"config.swift\".")
                filePath = swiftFilePath
                fileInfo = info
            } else if let info = await getInfo(jsonFilePath), info.type == .regular {
                // We have a JSON configuration file
                // print("Found \"config.json\".")
                filePath = jsonFilePath
                fileInfo = info
            } else {
                if strict {
                    throw .missingFile(directoryOrFilePath.string)
                } else {
                    return .default
                }
            }
        } else if directoryOrFileInfo.type == .regular {
            // We were given a path to a configuration file, let's check its extension to see if it's one of the 2 valid ones: .swift or .json
            guard let type = directoryOrFilePath.extension, (type == "swift" || type == "json") else {
                throw .invalidExtension
            }
            // We have a valid path and file information object
            filePath = directoryOrFilePath
            fileInfo = directoryOrFileInfo
        } else {
            // We only support folders or regular files
            // TODO: Allow symlinks
            throw .notFileOrFolder(directoryOrFilePath.string)
        }

        // Limit the file's size
        let maxSize = 1024 * 1024 // 1MB
        guard fileInfo.size <= maxSize else {
            throw .maximumSizeExceeded(size: Int(fileInfo.size), max: maxSize)
        }

        // Read the contents of the file regardless of the format
        let contents: ByteBuffer
        do {
            contents =  try await ByteBuffer(
                contentsOf: filePath,
                maximumSizeAllowed: .bytes(Int64(maxSize))
            )
        } catch {
            throw .unknownOpenReadIssue
        }

        let isJSON = filePath.extension == "json"
        let config: NodeConfig
        if isJSON {
            // For JSON configurations we simply decode into a NodeConfig instance
            let decoder = JSONDecoder()
            decoder.allowsJSON5 = true
            do {
                config = try decoder.decode(NodeConfig.self, from: contents)
            } catch {
                throw .decodingError
            }
        } else {
            // For Swift we need to put together a Swift source to pass via stdin to the interpreter…

            // First we need the unmodified contents of the actual configuration file
            guard let contentsAsString = String(data: Data(contents.readableBytesView), encoding: .utf8) else {
                throw .swiftConfigError
            }

            // We'll also need a copy of the NodeConfig struct and dependencies. This resource is produced by the CopyConfigSources package plugin
            guard let resource = Bundle.module.path(forResource: "NodeConfig", ofType: "swift.txt") else {
                throw .missingInternalResource
            }
            let resourceContents: Data
            do {
                resourceContents =  Data(try await ByteBuffer(
                    contentsOf: FilePath(resource),
                    maximumSizeAllowed: .bytes(Int64(maxSize))
                ).readableBytesView)
            } catch {
                throw .internalResourceUnavailable
            }
            let resourceText = String(data: resourceContents, encoding: .utf8)!

            // We will now build the Swift source code to pass to the Swift interpreter
            let configGenerationScript = """
            import Foundation
            \(resourceText)
            let encoder = JSONEncoder()
            \(contentsAsString)
            let data = try encoder.encode(config)
            print(String(data: data, encoding: .utf8)!)
            """

            // Create a process and pipes to pass the script to the interpreter
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["swift", "-"]
            let pipeIn = Pipe()
            process.standardInput = pipeIn
            let pipeOut = Pipe()
            process.standardOutput = pipeOut
            process.standardError = pipeOut

            // Set up the input pipe (stdin) to write the script
            let fileHandle = pipeIn.fileHandleForWriting
            fileHandle.write(configGenerationScript.data(using: .utf8)!)
            fileHandle.closeFile()

            // Run the process to obtain the configuration in JSON format
            let output: Data
            do {
                try process.run()
                // Read raw JSON data from the output pipe (stdout)
                output = pipeOut.fileHandleForReading.readDataToEndOfFile()
            } catch {
                throw .swiftScriptFailure
            }

            // Parse the JSON output, no JSON5 allowed here
            let decoder = JSONDecoder()
            do {
                config = try decoder.decode(NodeConfig.self, from: output)
            } catch {
                throw .decodingError
            }
        }
        return config
        // Success, display the result of the check
    }
}

private func getInfo(_ path: FilePath) async -> FileInfo? {
    do {
        return try await FileSystem.shared.info(forFileAt: path)
    } catch {
        fatalError()
    }
}
