import Foundation

extension Wallet {

    /// BIP13
    public static func getAddress(script: String, network: WalletNetwork) throws -> String {
        guard let script = Data(hex: script) else {
            throw WalletError.invalidHexString
        }
        return getAddress(script: script, network: network)
    }

    /// Decodes a script into its assembly textual representation.
    ///
    /// Part of BIP13.
    public static func getAddress(script: Data, network: WalletNetwork = .main) -> String {
        var data = Data()
        data.addBytes(of: UInt8(network.base58VersionScript))
        data.append(hash160(script))
        return Base58.base58CheckEncode(data)
    }

    /// Decodes a script into its assembly textual representation.
    /// - Parameters:
    ///   - script: The script in hex format.
    ///   - sigVersion: The signature version.
    /// - Returns: The script's assembly code.
    public static func decodeScript(script: String, sigVersion: SigVersion) throws -> String {
        guard let script = Data(hex: script) else {
            throw WalletError.invalidHexString
        }
        return decodeScript(script, sigVersion: sigVersion)
    }

    /// Decodes script data into its assembly textual representation.
    /// - Parameters:
    ///   - script: The script's data.
    ///   - sigVersion: The signature version.
    /// - Returns: The script's assembly code.
    public static func decodeScript(_ scriptData: Data, sigVersion: SigVersion = .base) -> String {
        let script = BitcoinScript(scriptData, sigVersion: sigVersion)
        return script.asm
    }
}
