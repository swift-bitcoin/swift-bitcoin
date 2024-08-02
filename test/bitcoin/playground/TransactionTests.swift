import Testing
import Foundation
import Bitcoin

struct TransactionTests {

    @Test("Deserialization")
    func deserialization() throws {
        let url = try #require(Bundle.module.url(forResource: "mainnet-transactions", withExtension: "json", subdirectory: "data"))
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()

        // New Foundation on Linux now supports JSON5
        decoder.allowsJSON5 = true

        let TxInfoItems = try decoder.decode([TxInfo].self, from: data)
        for txInfo in TxInfoItems {
            guard
                let expectedTransactionData = Data(hex: txInfo.hex),
                let tx = BitcoinTransaction(expectedTransactionData)
            else {
                Issue.record("Transaction data could not be decoded."); continue
            }

            #expect(tx.data == expectedTransactionData)

            let expectedVersion = txInfo.version
            #expect(tx.version.versionValue == expectedVersion)

            let expectedLocktime = txInfo.locktime
            #expect(tx.locktime.locktimeValue == expectedLocktime)

            guard let expectedID = Data(hex: txInfo.txid), let expectedWitnessID = Data(hex: txInfo.hash) else {
                Issue.record("Transaction ID data could not be decoded."); continue
            }
            #expect(tx.identifier == expectedID)
            #expect(tx.witnessIdentifier == expectedWitnessID)

            let expectedSize = txInfo.size
            #expect(tx.size == expectedSize)

            let expectedInputCount = txInfo.vin.count
            let expectedOutputCount = txInfo.vout.count
            #expect(tx.inputs.count == expectedInputCount)
            #expect(tx.outputs.count == expectedOutputCount)

            for i in txInfo.vin.indices {
                let vinData = txInfo.vin[i]
                let input = tx.inputs[i]

                let expectedSequence = vinData.sequence
                #expect(input.sequence.sequenceValue == expectedSequence)

                if let coinbase = vinData.coinbase {
                    guard let expectedCoinbase = Data(hex: coinbase) else {
                        Issue.record("Transaction input \(i) coinbase data could not be decoded."); continue
                    }

                    let expectedOutpoint = TransactionOutpoint.coinbase
                    #expect(input.outpoint == expectedOutpoint)

                    let expectedScript = BitcoinScript(expectedCoinbase)
                    #expect(input.script == expectedScript)

                } else if let txid = vinData.txid, let expectedOutput = vinData.vout, let scriptSig = vinData.scriptSig, let expectedScriptData = Data(hex: scriptSig.hex) {
                    guard let expectedTransaction = Data(hex: txid) else {
                        Issue.record("Transaction input \(i) transaction ID data could not be decoded."); continue
                    }

                    #expect(input.outpoint.transactionIdentifier == expectedTransaction)
                    #expect(input.outpoint.outputIndex == expectedOutput)
                    let expectedScript = BitcoinScript(expectedScriptData)
                    #expect(input.script == expectedScript)

                    if let witness = vinData.txinwitness {
                        let expectedWitnessData = witness.compactMap { Data(hex: $0) }
                        let expectedWitness = InputWitness(expectedWitnessData)
                        #expect(input.witness == expectedWitness)
                    }
                } else {
                    Issue.record("Transaction input \(i) data could not be decoded."); continue
                }
            }
            for i in txInfo.vout.indices {
                let voutData = txInfo.vout[i]
                let output = tx.outputs[i]

                let expectedValue = voutData.value
                #expect(Double(output.value) / 100_000_000 == expectedValue)

                guard let expectedScriptData = Data(hex: voutData.scriptPubKey.hex) else {
                    Issue.record("Transaction output \(i) script data could not be decoded."); continue
                }
                let expectedScript = BitcoinScript(expectedScriptData)
                #expect(output.script == expectedScript)
            }
        }
    }
}
