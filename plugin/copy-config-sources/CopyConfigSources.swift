import PackagePlugin
import Foundation

/// Copies the contents of `NodeConfig.swift` into a `NodeConfig.swift.txt` file in the plugin's output folder. The copied source code will be included in the resources bundle and prepended to configuration scripts.
///
/// If stuck with an old version of the file, the copy can be manually removed before running/building again:
///
/// ```sh
/// rm .build/plugins/outputs/swift-bitcoin/BitcoinNode/destination/CopyConfigSources/NodeConfig.swift.txt
/// ```
@main
struct CopyConfigSources: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) throws(PluginError) -> [Command] {

        guard let sourceModule = target.sourceModule else {
            throw .missingSourceModule
        }

        // We are acting whenever there's a NodeConfig.swift available.
        guard let sourceFile = sourceModule.sourceFiles.first(where: { $0.url.lastPathComponent == "NodeConfig.swift" })?.url else {
            return []
        }

        let destinationFile = context.pluginWorkDirectoryURL.appending(component: "NodeConfig.swift.txt")

        // Create a build command to copy the file and rename it
        let copyCommand = Command.prebuildCommand(
            displayName: "",
            // executable: context.tool(named: "/bin/cp").url,
            executable: URL(fileURLWithPath: "/bin/cp"),
            arguments: [sourceFile.relativePath, destinationFile.relativePath],
            environment: [:],
            outputFilesDirectory: context.pluginWorkDirectoryURL)

        // let copyCommand = Command.buildCommand(
        //     displayName: nil,
        //     executable: URL(fileURLWithPath: "/bin/cp"),
        //     arguments: [sourceFile.relativePath, destinationFile.relativePath],
        //     environment: [:],
        //     inputFiles: [sourceFile],
        //     outputFiles: [destinationFile])

        return [copyCommand]
    }
}

enum PluginError: Error {
    case missingSourceModule
}
