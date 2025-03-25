import PackagePlugin
import Foundation

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
        //     displayName: .none,
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
