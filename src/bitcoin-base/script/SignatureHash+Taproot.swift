import Foundation
import BitcoinCrypto

extension SignatureHash {

    /// BIP341
    public struct Taproot: Equatable, Sendable {

        private init() { fatalError() }

        public let data: Data
    }
}

extension SignatureHash.Taproot {

    public init(tx: Transaction, input: Int, sighashType: SighashType?, prevouts: [TransactionOutput], tapscriptExtension: TapscriptExtension? = nil) {
        var cache = SignatureMessage.Taproot.Cache()
        self.init(tx: tx, input: input, sighashType: sighashType, prevouts: prevouts, tapscriptExtension: tapscriptExtension, sighashCache: &cache)
    }

    init(tx: Transaction, input: Int, sighashType: SighashType?, prevouts: [TransactionOutput], tapscriptExtension: TapscriptExtension? = nil, sighashCache: inout SignatureMessage.Taproot.Cache) {

        var hasher = SHA256(tag: "TapSighash")

        let message = SignatureMessage.Taproot(tx: tx, input: input, sighashType: sighashType, prevouts: prevouts, tapscriptExtension: tapscriptExtension, sighashCache: &sighashCache)

        hasher.update(data: message.data)
        if let tapscriptExtension {
            hasher.update(data: tapscriptExtension.data)
        }
        data = Data(hasher.finalize())
    }
}
