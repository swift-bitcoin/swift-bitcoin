import Foundation
import _NIOFileSystem

extension NodeConfig {

    static func checkLocation(_ location: String) async throws(ParseError) -> FilePath {
        // Check whether we are accessing the default location
        let isDefault = location == Self.defaultLocation

        // Find the actual configuration file
        let fs = FileSystem.shared
        let directoryPath = FilePath(location)
        let directoryInfo: FileInfo?
        do {
            directoryInfo = try await fs.info(forFileAt: directoryPath)
        } catch {
            throw .locateDirectory(location)
        }
        guard let directoryInfo else {
            guard isDefault else {
                throw .readDirectory(location)
            }
            do {
                try await fs.createDirectory(at: directoryPath, withIntermediateDirectories: true)
            } catch {
                throw .internalResourceUnavailable
            }
            return directoryPath
        }
        guard directoryInfo.type == .directory else {
            throw .notDirectory(directoryPath.string)
        }
        return directoryPath
    }
}

private func getInfo(_ path: FilePath) async -> FileInfo? {
    do {
        return try await FileSystem.shared.info(forFileAt: path)
    } catch {
        fatalError()
    }
}
