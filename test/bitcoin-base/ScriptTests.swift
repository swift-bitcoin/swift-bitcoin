import Testing
import Foundation
@testable import BitcoinBase

struct ScriptTests {

    /// It is evaluated as if there was a crediting coinbase transaction with two 0 pushes as scriptSig, and one output of 0 satoshi and given scriptPubKey, followed by a spending transaction which spends this output as only input (and correct prevout hash), using the given scriptSig. All nLockTimes are 0, all nSequences are max.
    @Test("Script test vectors", arguments: [
        // Format is: ([wit..., amount]?, scriptSig, scriptPubKey, flags, expected_scripterror, ... comments)
        TestVector(.empty, [ScriptOperation.depth, .zero, .equal], [.strictEncoding, .payToScriptHash], true, [], "Test the test: we should have an empty stack after scriptSig evaluation"),
            // Some missing _test the test_ tests involving spaces in data which are not applicable here.
            .init(.init([.constant(1), .constant(2)]), .init([.constant(2), .equalVerify, .constant(1), .equal]), [.strictEncoding, .payToScriptHash], true, [], "Similarly whitespace around and between symbols"),
            // Additional missing _test the test_ tests involving spaces in data which are not applicable here.

            // MARK: - Actual script tests.
            .init(.init([.constant(1)]), .empty, [.strictEncoding, .payToScriptHash], true, [], ""),
            .init(.init([.pushBytes(Data([0x01, 0x00]))]), .empty, [.strictEncoding, .payToScriptHash], true, [], "all bytes are significant, not only the last one"),
            .init(.init([.pushBytes(Data([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x10]))]), .empty, [.strictEncoding, .payToScriptHash], true, [], "equals zero when cast to Int64"),

            // Missing tests here.

            // MARK: - Some basic segwit checks
            .init([.init([0x00])], 0, .empty, .init([.zero, .pushBytes(Data([0x20, 0x6e, 0x34, 0x0b, 0x9c, 0xff, 0xb3, 0x7a, 0x98, 0x9c, 0xa5, 0x44, 0xe6, 0xbb, 0x78, 0x0a, 0x2c, 0x78, 0x90, 0x1d, 0x3f, 0xb3, 0x37, 0x38, 0x76, 0x85, 0x11, 0xa3, 0x06, 0x17, 0xaf, 0xa0, 0x1d]))]), [.payToScriptHash, .witness], false, [], "Invalid witness script"),

            .init([.init([0x33 /* or 51 (?) */])], 0, .empty, .init([.zero, .pushBytes(Data([0x20, 0x6e, 0x34, 0x0b, 0x9c, 0xff, 0xb3, 0x7a, 0x98, 0x9c, 0xa5, 0x44, 0xe6, 0xbb, 0x78, 0x0a, 0x2c, 0x78, 0x90, 0x1d, 0x3f, 0xb3, 0x37, 0x38, 0x76, 0x85, 0x11, 0xa3, 0x06, 0x17, 0xaf, 0xa0, 0x1d]))]), [.payToScriptHash, .witness], false, [.witnessProgramWrongLength /* WITNESS_PROGRAM_MISMATCH */], "Witness script hash mismatch"),
    ])
    func allVectors(test: TestVector) throws {
        let txCredit = BitcoinTransaction(
            inputs: [
                .init(outpoint: .coinbase, sequence: .final, script: .init([.zero, .zero])),
            ],
            outputs: [
                .init(value: test.amount, script: test.scriptPubKey)
            ]
        )

        let witness = if let witnessElements = test.witness {
            InputWitness(witnessElements)
        } else {
            InputWitness?.none
        }

        let txSpend = BitcoinTransaction(
            inputs: [
                .init(outpoint: txCredit.outpoint(for: 0)!, sequence: .final, script: test.scriptSig, witness: witness),
            ],
            outputs: [
                .init(value: txCredit.outputs[0].value, script: .empty)
            ]
        )
        let result = txSpend.verifyScript(previousOutputs: [txCredit.outputs[0]], config: test.flags)
        if test.evalTrue {
            #expect(result)
        } else if test.expectedErrors.isEmpty {
            #expect(!result)
        } else {
            #expect {
                try txSpend.verifyScript(inputIndex: 0, previousOutputs: [txCredit.outputs[0]], config: test.flags)
            } throws: { error in
                guard let error = error as? ScriptError else {
                    return false
                }
                return error == test.expectedErrors[0]
            }
        }
    }

    struct TestVector {
        init(
            _ scriptSig: BitcoinScript,
            _ scriptPubKey: BitcoinScript,
            _ flags: ScriptConfig,
            _ evalTrue: Bool,
            _ expectedErrors: [ScriptError],
            _ comments: String
        ) {
            self.init(
                .none,
                0,
                scriptSig,
                scriptPubKey,
                flags,
                evalTrue,
                expectedErrors,
                comments
            )
        }

        init(
            _ witness: [Data]?,
            _ amount: BitcoinAmount,
            _ scriptSig: BitcoinScript,
            _ scriptPubKey: BitcoinScript,
            _ flags: ScriptConfig,
            _ evalTrue: Bool,
            _ expectedErrors: [ScriptError],
            _ comments: String
        ) {
            self.witness = witness
            self.amount = amount
            self.scriptSig = scriptSig
            self.scriptPubKey = scriptPubKey
            self.flags = flags
            self.evalTrue = evalTrue
            self.expectedErrors = expectedErrors
            self.comments = comments
        }

        let witness: [Data]?
        let amount: BitcoinAmount
        let scriptSig: BitcoinScript
        let scriptPubKey: BitcoinScript
        let flags: ScriptConfig
        let evalTrue: Bool
        let expectedErrors: [ScriptError]
        let comments: String
    }
}
