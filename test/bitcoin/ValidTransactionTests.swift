import XCTest
import Bitcoin

fileprivate struct TestVector {

    struct PreviousOutput {
        let transactionIdentifier: String
        let outputIndex: Int
        let amount: UInt
        let scriptOperations: [ScriptOperation]
    }

    let previousOutputs: [PreviousOutput]
    let serializedTransaction: String
    let excludedVerifyFlags: String
}

fileprivate let testVectors: [TestVector] = [

    // A nearly-standard transaction with CHECKSIGVERIFY 1 instead of CHECKSIG
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .dup,
                    .hash160,
                    .pushBytes(.init(hex: "5b6462475454710f3c22f5fdf0b40704c92f25c3")!),
                    .equalVerify,
                    .checkSigVerify,
                    .constant(1)
                ]
            )
        ],
        serializedTransaction: "01000000010001000000000000000000000000000000000000000000000000000000000000000000006a473044022067288ea50aa799543a536ff9306f8e1cba05b9c6b10951175b924f96732555ed022026d7b5265f38d21541519e4a1e55044d5b9e17e15cdbaf29ae3792e99e883e7a012103ba8c8b86dea131c22ab967e6dd99bdae8eff7a1f75a2c35f1f944109e3fe5e22ffffffff010000000000000000015100000000",
        excludedVerifyFlags: "NONE"
    ),

    // Same as above, but with the signature duplicated in the scriptPubKey with the proper pushdata prefix
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .dup,
                    .hash160,
                    .pushBytes(.init(hex: "5b6462475454710f3c22f5fdf0b40704c92f25c3")!),
                    .equalVerify,
                    .checkSigVerify,
                    .constant(1),
                    .pushBytes(.init(hex: "3044022067288ea50aa799543a536ff9306f8e1cba05b9c6b10951175b924f96732555ed022026d7b5265f38d21541519e4a1e55044d5b9e17e15cdbaf29ae3792e99e883e7a01")!)
                ]
            )
        ],
        serializedTransaction: "01000000010001000000000000000000000000000000000000000000000000000000000000000000006a473044022067288ea50aa799543a536ff9306f8e1cba05b9c6b10951175b924f96732555ed022026d7b5265f38d21541519e4a1e55044d5b9e17e15cdbaf29ae3792e99e883e7a012103ba8c8b86dea131c22ab967e6dd99bdae8eff7a1f75a2c35f1f944109e3fe5e22ffffffff010000000000000000015100000000",
        excludedVerifyFlags: "CLEANSTACK,CONST_SCRIPTCODE"
    ),

    // The following tests for the presence of a bug in the handling of `SIGHASH_SINGLE`
    // It results in signing the constant 1, instead of something generated based on the transaction
    // when the input doing the signing has an index greater than the maximum output index.
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000200",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .constant(1)
                ]
            ),
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .dup,
                    .hash160,
                    .pushBytes(.init(hex: "e52b482f2faa8ecbf0db344f93c84ac908557f33")!),
                    .equalVerify,
                    .checkSig
                ]
            )
        ],
        serializedTransaction: "01000000020002000000000000000000000000000000000000000000000000000000000000000000000151ffffffff0001000000000000000000000000000000000000000000000000000000000000000000006b483045022100c9cdd08798a28af9d1baf44a6c77bcc7e279f47dc487c8c899911bc48feaffcc0220503c5c50ae3998a733263c5c0f7061b483e2b56c4c41b456e7d2f5a78a74c077032102d5c25adb51b61339d2b05315791e21bbe80ea470a49db0135720983c905aace0ffffffff010000000000000000015100000000",
        excludedVerifyFlags: "CLEANSTACK"
    ),

    // Simple transaction with first input is signed with SIGHASH_ALL, second with SIGHASH_ANYONECANPAY
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(hex: "035e7f0d4d0841bcd56c39337ed086b1a633ee770c1ffdd94ac552a95ac2ce0efc")!),
                    .checkSig
                ]
            ),
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000200",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(hex: "035e7f0d4d0841bcd56c39337ed086b1a633ee770c1ffdd94ac552a95ac2ce0efc")!),
                    .checkSig
                ]
            )
        ],
        serializedTransaction: "010000000200010000000000000000000000000000000000000000000000000000000000000000000049483045022100d180fd2eb9140aeb4210c9204d3f358766eb53842b2a9473db687fa24b12a3cc022079781799cd4f038b85135bbe49ec2b57f306b2bb17101b17f71f000fcab2b6fb01ffffffff0002000000000000000000000000000000000000000000000000000000000000000000004847304402205f7530653eea9b38699e476320ab135b74771e1c48b81a5d041e2ca84b9be7a802200ac8d1f40fb026674fe5a5edd3dea715c27baa9baca51ed45ea750ac9dc0a55e81ffffffff010100000000000000015100000000",
        excludedVerifyFlags: "NONE"
    ),

    // Same as above, but we change the sequence number of the first input to check that SIGHASH_ANYONECANPAY is being followed
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(hex: "035e7f0d4d0841bcd56c39337ed086b1a633ee770c1ffdd94ac552a95ac2ce0efc")!),
                    .checkSig
                ]
            ),
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000200",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(hex: "035e7f0d4d0841bcd56c39337ed086b1a633ee770c1ffdd94ac552a95ac2ce0efc")!),
                    .checkSig
                ]
            )
        ],
        serializedTransaction: "01000000020001000000000000000000000000000000000000000000000000000000000000000000004948304502203a0f5f0e1f2bdbcd04db3061d18f3af70e07f4f467cbc1b8116f267025f5360b022100c792b6e215afc5afc721a351ec413e714305cb749aae3d7fee76621313418df101010000000002000000000000000000000000000000000000000000000000000000000000000000004847304402205f7530653eea9b38699e476320ab135b74771e1c48b81a5d041e2ca84b9be7a802200ac8d1f40fb026674fe5a5edd3dea715c27baa9baca51ed45ea750ac9dc0a55e81ffffffff010100000000000000015100000000",
        excludedVerifyFlags: "LOW_S"
    ),


    // Test that SignatureHash() removes OP_CODESEPARATOR with FindAndDelete()
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "bc7fd132fcf817918334822ee6d9bd95c889099c96e07ca2c1eb2cc70db63224",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .codeSeparator,
                    .pushBytes(Data(hex: "038479a0fa998cd35259a2ef0a7a5c68662c1474f88ccb6d08a7677bbec7f22041")!),
                    .checkSig
                ]
            ),
        ],
        serializedTransaction: "01000000012432b60dc72cebc1a27ce0969c0989c895bdd9e62e8234839117f8fc32d17fbc000000004a493046022100a576b52051962c25e642c0fd3d77ee6c92487048e5d90818bcf5b51abaccd7900221008204f8fb121be4ec3b24483b1f92d89b1b0548513a134e345c5442e86e8617a501ffffffff010000000000000000016a00000000",
        excludedVerifyFlags: "CONST_SCRIPTCODE,LOW_S"
    ),

    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "83e194f90b6ef21fa2e3a365b63794fb5daa844bdc9b25de30899fcfe7b01047",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .codeSeparator,
                    .codeSeparator,
                    .pushBytes(Data(hex: "038479a0fa998cd35259a2ef0a7a5c68662c1474f88ccb6d08a7677bbec7f22041")!),
                    .checkSig
                ]
            ),
        ],
        serializedTransaction: "01000000014710b0e7cf9f8930de259bdc4b84aa5dfb9437b665a3e3a21ff26e0bf994e183000000004a493046022100a166121a61b4eeb19d8f922b978ff6ab58ead8a5a5552bf9be73dc9c156873ea02210092ad9bc43ee647da4f6652c320800debcf08ec20a094a0aaf085f63ecb37a17201ffffffff010000000000000000016a00000000",
        excludedVerifyFlags: "CONST_SCRIPTCODE,LOW_S"
    ),

    // Hashed data starts at the CODESEPARATOR
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "326882a7f22b5191f1a0cc9962ca4b878cd969cf3b3a70887aece4d801a0ba5e",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(Data(hex: "038479a0fa998cd35259a2ef0a7a5c68662c1474f88ccb6d08a7677bbec7f22041")!),
                    .codeSeparator,
                    .checkSig
                ]
            ),
        ],
        serializedTransaction: "01000000015ebaa001d8e4ec7a88703a3bcf69d98c874bca6299cca0f191512bf2a7826832000000004948304502203bf754d1c6732fbf87c5dcd81258aefd30f2060d7bd8ac4a5696f7927091dad1022100f5bcb726c4cf5ed0ed34cc13dadeedf628ae1045b7cb34421bc60b89f4cecae701ffffffff010000000000000000016a00000000",
        excludedVerifyFlags: "CONST_SCRIPTCODE,LOW_S"
    ),

]

final class ValidTransactionTests: XCTestCase {

    override class func setUp() {
        eccStart()
    }

    override class func tearDown() {
        eccStop()
    }

    func testValidTransactions() throws {
        for vector in testVectors {
            guard
                let expectedTransactionData = Data(hex: vector.serializedTransaction),
                let tx = Transaction(expectedTransactionData)
            else {
                XCTFail(); return
            }
            let previousOutputs = vector.previousOutputs.map { previousOutput in
                Output(value: previousOutput.amount, script: ParsedScript(previousOutput.scriptOperations))
            }
            let result = tx.verify(previousOutputs: previousOutputs)
            XCTAssert(result)
        }
    }
}
