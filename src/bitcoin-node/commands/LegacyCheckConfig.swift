import ArgumentParser
import Foundation
import NIOCore
import _NIOFileSystem

/// Legacy check configuration command; uses old ``NodeConfig/parse(_:strict:)`` instead of `Configuration`.
struct LegacyCheckConfig: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: "Verifies the configuration file."
    )

    @Argument(help: "The absolute path to either the directory containing Swift Bitcoin's configuration file or the configuration file itself, e.g. \"/some/directory/myConfig.json\".")
    var location = NodeConfig.defaultLocation

    mutating func run() async throws(ValidationError) {
        let config: NodeConfig
        do {
            try config = await NodeConfig.parse(location, strict: true)
        } catch {
            throw ValidationError(error)
        }
        // Success, display the result of the check

        // Additional round trip verification
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let roundtrip = try? encoder.encode(config) else {
            throw ValidationError("Issue verifying decoding-encoding round trip.")
        }

        print("Configuration file verification passed with following parameters:\n")
        print(String(data: roundtrip, encoding: .utf8)!)
    }
}

private func getInfo(_ path: FilePath) async -> FileInfo? {
    do {
        return try await FileSystem.shared.info(forFileAt: path)
    } catch {
        fatalError()
    }
}
