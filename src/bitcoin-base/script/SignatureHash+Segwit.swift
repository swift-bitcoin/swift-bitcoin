import Foundation
import BitcoinCrypto

extension SignatureHash {

    /// BIP143
    public struct Segwit: Equatable, Sendable {

        private init() { fatalError() }

        public let data: Data
    }
}

extension SignatureHash.Segwit {
    public init(tx: Transaction, input: Int, sighashType: SighashType, scriptCode: Data?, prevout: TransactionOutput) {
        precondition(scriptCode != nil || (prevout.script.isSegwit && prevout.script.witnessProgram.count == Hash160.Digest.byteCount))
        let scriptCode = scriptCode ?? Script.segwitPKHScriptCode(prevout.script.witnessProgram).binaryData

        let message = SignatureMessage.Segwit(tx: tx, input: input, sighashType: sighashType, scriptCode: scriptCode, prevout: prevout)
        data = Data(Hash256.hash(data: message.data))
    }
}
