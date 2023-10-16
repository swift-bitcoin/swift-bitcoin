import XCTest
import Bitcoin

final class TransactionTests: XCTestCase {

    override class func setUp() {
        eccStart()
    }

    override class func tearDown() {
        eccStop()
    }

    func testDeserialization() throws {
        guard let url = Bundle.module.url(forResource: "mainnet-transactions", withExtension: "json", subdirectory: "data/transactions") else {
            XCTFail(); return
        }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()

        // Linux Foundation does not support JSON5
        // decoder.allowsJSON5 = true

        let TxInfoItems = try decoder.decode([TxInfo].self, from: data)
        for txInfo in TxInfoItems {
            guard
                let expectedTransactionData = Data(hex: txInfo.hex),
                let tx = Transaction(expectedTransactionData)
            else {
                XCTFail(); return
            }

            XCTAssertEqual(tx.data, expectedTransactionData)

            let expectedVersion = txInfo.version
            XCTAssertEqual(tx.version.versionValue, expectedVersion)

            let expectedLocktime = txInfo.locktime
            XCTAssertEqual(tx.locktime.locktimeValue, expectedLocktime)

            guard let expectedID = Data(hex: txInfo.txid), let expectedWitnessID = Data(hex: txInfo.hash) else {
                XCTFail(); return
            }
            XCTAssertEqual(tx.identifier, expectedID)
            XCTAssertEqual(tx.witnessIdentifier, expectedWitnessID)

            let expectedSize = txInfo.size
            XCTAssertEqual(tx.size, expectedSize)

            let expectedInputCount = txInfo.vin.count
            let expectedOutputCount = txInfo.vout.count
            XCTAssertEqual(tx.inputs.count, expectedInputCount)
            XCTAssertEqual(tx.outputs.count, expectedOutputCount)

            for i in txInfo.vin.indices {
                let vinData = txInfo.vin[i]
                let input = tx.inputs[i]

                let expectedSequence = vinData.sequence
                XCTAssertEqual(input.sequence.sequenceValue, expectedSequence)

                if let coinbase = vinData.coinbase {
                    guard let expectedCoinbase = Data(hex: coinbase) else {
                        XCTFail(); return
                    }

                    let expectedOutpoint = Outpoint.coinbase
                    XCTAssertEqual(input.outpoint, expectedOutpoint)

                    let expectedScript = SerializedScript(expectedCoinbase)
                    XCTAssertEqual(input.script, expectedScript)

                } else if let txid = vinData.txid, let expectedOutput = vinData.vout, let scriptSig = vinData.scriptSig, let expectedScriptData = Data(hex: scriptSig.hex) {
                    guard let expectedTransaction = Data(hex: txid) else {
                        XCTFail(); return
                    }

                    XCTAssertEqual(input.outpoint.transactionIdentifier, expectedTransaction)
                    XCTAssertEqual(input.outpoint.outputIndex, expectedOutput)
                    let expectedScript = SerializedScript(expectedScriptData)
                    XCTAssertEqual(input.script, expectedScript)

                    if let witness = vinData.txinwitness {
                        let expectedWitnessData = witness.compactMap { Data(hex: $0) }
                        let expectedWitness = Witness(expectedWitnessData)
                        XCTAssertEqual(input.witness, expectedWitness)
                    }
                } else {
                    XCTFail(); return
                }
            }
            for i in txInfo.vout.indices {
                let voutData = txInfo.vout[i]
                let output = tx.outputs[i]

                let expectedValue = voutData.value
                XCTAssertEqual(Double(output.value) / 100_000_000, expectedValue)

                guard let expectedScriptData = Data(hex: voutData.scriptPubKey.hex) else {
                    XCTFail(); return
                }
                let expectedScript = SerializedScript(expectedScriptData)
                XCTAssertEqual(output.script, expectedScript)
            }
        }
    }
}
