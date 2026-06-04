import Configuration
import Foundation

struct SwiftSnapshot {
    let jsonSnapshot: JSONSnapshot

    enum SwiftSnapshotError: Error {
        case maximumSizeExceeded(size: Int, max: Int), swiftConfigError, missingInternalResource, internalResourceUnavailable, swiftScriptFailure, decodingError
    }
}

#if canImport(Foundation.NSTask)
import class Foundation.NSTask.Process
#endif

extension SwiftSnapshot: FileConfigSnapshot {
    public init(data: RawSpan, providerName: String, parsingOptions: JSONSnapshot.ParsingOptions) throws {

#if !canImport(Foundation.NSTask)
    fatalError("Foundation.NSTask.Process class not available")
#endif

    // Limit the file's size
    let maxSize = 1024 * 1024 // 1MB
    guard data.byteCount <= maxSize else {
        throw SwiftSnapshotError.maximumSizeExceeded(size: Int(data.byteCount), max: maxSize)
    }

    // For Swift we need to put together a Swift source to pass via stdin to the interpreter…

    // First we need the unmodified contents of the actual configuration file
    guard let contentsAsString = String(data: Data(data), encoding: .utf8) else {
        throw SwiftSnapshotError.swiftConfigError
    }

    // We'll also need a copy of the NodeConfig struct and dependencies. This resource is produced by the CopyConfigSources package plugin
    guard let resource = Bundle.module.path(forResource: "NodeConfig", ofType: "swift.txt") else {
        throw SwiftSnapshotError.missingInternalResource
    }

    let resourceContents = try Data(contentsOf: URL(filePath: resource))

    // Can't use NIO here because this initializer is not async
    // let resourceContents: Data
    // do {
    //     resourceContents =  Data(try await ByteBuffer(
    //         contentsOf: FilePath(resource),
    //         maximumSizeAllowed: .bytes(Int64(maxSize))
    //     ).readableBytesView)
    // } catch {
    //     throw SwiftSnapshotError.internalResourceUnavailable
    // }

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
        throw SwiftSnapshotError.swiftScriptFailure
    }
        jsonSnapshot = try .init(data: output.bytes, providerName: providerName, parsingOptions: parsingOptions)
    }
}

extension SwiftSnapshot: ConfigSnapshot {
    var providerName: String {
        jsonSnapshot.providerName
    }

    public func value(forKey key: AbsoluteConfigKey, type: ConfigType) throws -> LookupResult {
        try jsonSnapshot.value(forKey: key, type: type)
    }
}

extension SwiftSnapshot: CustomStringConvertible {
    public var description: String {
        jsonSnapshot.description
    }
}

extension SwiftSnapshot: CustomDebugStringConvertible {
    public var debugDescription: String {
        jsonSnapshot.debugDescription
    }
}

extension Data {
    /// Creates data from a raw span.
    /// - Parameter span: The raw span whose bytes to copy into a new Data.
    internal init(_ span: RawSpan) {
        self = span.withUnsafeBytes { pointer in
            guard let base = pointer.baseAddress else {
                return Data()
            }
            return Data(bytes: base, count: pointer.count)
        }
    }
}
