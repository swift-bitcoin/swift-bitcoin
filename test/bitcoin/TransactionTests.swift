import XCTest
@testable import Bitcoin

final class TransactionTests: XCTestCase {

    func testDeserialization() throws {
        guard let url = Bundle.module.url(forResource: "mainnet-transactions", withExtension: "json", subdirectory: "data/transactions") else {
            XCTFail()
            return
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
            XCTAssertEqual(tx.version.rawValue, expectedVersion)

            let expectedLocktime = txInfo.locktime
            XCTAssertEqual(tx.locktime.rawValue, expectedLocktime)

            guard let expectedID = Data(hex: txInfo.txid), let expectedWitnessID = Data(hex: txInfo.hash) else {
                XCTFail(); return
            }
            XCTAssertEqual(tx.id, expectedID)
            XCTAssertEqual(tx.witnessID, expectedWitnessID)

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
                XCTAssertEqual(input.sequence.rawValue, expectedSequence)

                if let coinbase = vinData.coinbase {
                    guard let expectedCoinbase = Data(hex: coinbase) else {
                        XCTFail()
                        return
                    }

                    let expectedOutpoint = Outpoint.coinbase
                    XCTAssertEqual(input.outpoint, expectedOutpoint)

                    let expectedScript = SerializedScript(expectedCoinbase)
                    XCTAssertEqual(input.script, expectedScript)

                } else if let txid = vinData.txid, let expectedOutput = vinData.vout, let scriptSig = vinData.scriptSig, let expectedScriptData = Data(hex: scriptSig.hex) {
                    guard let expectedTransaction = Data(hex: txid) else {
                        XCTFail()
                        return
                    }

                    XCTAssertEqual(input.outpoint.transaction, expectedTransaction)
                    XCTAssertEqual(input.outpoint.output, expectedOutput)
                    let expectedScript = SerializedScript(expectedScriptData)
                    XCTAssertEqual(input.script, expectedScript)

                    if let witness = vinData.txinwitness {
                        let expectedWitnessData = witness.compactMap { Data(hex: $0) }
                        let expectedWitness = Witness(expectedWitnessData)
                        XCTAssertEqual(input.witness, expectedWitness)
                    }
                } else {
                    XCTFail()
                    return
                }
            }
            for i in txInfo.vout.indices {
                let voutData = txInfo.vout[i]
                let output = tx.outputs[i]

                let expectedValue = voutData.value
                XCTAssertEqual(Double(output.value) / 100_000_000, expectedValue)

                guard let expectedScriptData = Data(hex: voutData.scriptPubKey.hex) else {
                    XCTFail()
                    return
                }
                let expectedScript = SerializedScript(expectedScriptData)
                XCTAssertEqual(output.script, expectedScript)
            }
        }
    }

    func testTransactionRoundtrip() throws {
        // A coinbase transaction
        let tx = Transaction(
            version: .v1,
            locktime: .init(0),
            inputs: [
                .init(
                    outpoint: .coinbase,
                    sequence: .init(0xffffffff),
                    script: .init(Data([
                        0x05, // OP_PUSHBYTES_5
                        0x68, 0x65, 0x6c, 0x6c, 0x6f, // hello
                    ]))
                )
            ],
            outputs: [
                .init(
                    value: 5_000_000_000, // 50 BTC
                    script: .init(Data([
                        0x6a, // OP_RETURN
                        0x62, 0x79, 0x65 // bye
                    ]))
                )
            ])
        let data = tx.data
        guard let tx_ = Transaction(data) else {
            XCTFail()
            return
        }
        XCTAssertEqual(data, tx_.data)
    }
}
