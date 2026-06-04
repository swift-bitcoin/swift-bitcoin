import Foundation
import ArgumentParser

struct CheckConfig: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: "Verifies the configuration file."
    )

    @OptionGroup var configOptions: ConfigOptions

    mutating func run() async throws(ValidationError) {
        let nodeConfig = try await NodeConfig.loadConfiguration(configOptions)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try! encoder.encode(nodeConfig)
        print(String(data: data, encoding: .utf8)!)
        // debugPrint(nodeConfig)
    }
}
