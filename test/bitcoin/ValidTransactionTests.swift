import XCTest
@testable import Bitcoin

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
            XCTAssertNoThrow(try tx.check())
            var excludeFlags = Set(vector.verifyFlags.split(separator: ","))
            excludeFlags.remove("NONE")
            var config = ScriptConfigurarion.standard
            if excludeFlags.contains("NULLDUMMY") {
                config.checkNullDummy = false
            }
            if excludeFlags.contains("LOW_S") {
                config.checkLowS = false
            }
            if excludeFlags.contains("DERSIG") {
                config.checkStrictDER = false
            }
            let result = tx.verify(previousOutputs: previousOutputs, configuration: config)
            XCTAssert(result)
            if !excludeFlags.isEmpty && !excludeFlags.contains("CLEANSTACK") && !excludeFlags.contains("CONST_SCRIPTCODE") && !excludeFlags.contains("STRICTENC") && !excludeFlags.contains("NULLFAIL") {
                let failure = tx.verify(previousOutputs: previousOutputs, configuration: .standard)
                XCTAssertFalse(failure)
            }
        }
    }
}

fileprivate struct TestVector {

    struct PreviousOutput {
        let transactionIdentifier: String
        let outputIndex: Int
        let amount: Int
        let scriptOperations: [ScriptOperation]
    }

    let previousOutputs: [PreviousOutput]
    let serializedTransaction: String
    let verifyFlags: String
}

fileprivate let testVectors: [TestVector] = [

    // The following is 23b397edccd3740a74adb603c9756370fafcde9bcc4483eb271ecad09a94dd63
    // It is of particular interest because it contains an invalidly-encoded signature which OpenSSL accepts
    // See http://r6.ca/blog/20111119T211504Z.html
    // It is also the first OP_CHECKMULTISIG transaction in standard form
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "60a20bd93aa49ab4b28d514ec10b06e1829ce6818ec06cd3aabd013ebcdc4bb1",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .constant(1),
                    .pushBytes(.init(hex: "04cc71eb30d653c0c3163990c47b976f3fb3f37cccdcbedb169a1dfef58bbfbfaff7d8a473e7e2e6d317b87bafe8bde97e3cf8f065dec022b51d11fcdd0d348ac4")!),
                    .pushBytes(.init(hex: "0461cbdcc5409fb4b4d42b51d33381354d80e550078cb532a34bfa2fcfdeb7d76519aecc62770f5b0e4ef8551946d8a540911abe3e7854a26f39f58b25c15342af")!),
                    .constant(2),
                    .checkMultiSig
                ]
            )
        ],
        serializedTransaction: "0100000001b14bdcbc3e01bdaad36cc08e81e69c82e1060bc14e518db2b49aa43ad90ba26000000000490047304402203f16c6f40162ab686621ef3000b04e75418a0c0cb2d8aebeac894ae360ac1e780220ddc15ecdfc3507ac48e1681a33eb60996631bf6bf5bc0a0682c4db743ce7ca2b01ffffffff0140420f00000000001976a914660d4ef3a743e3e696ad990364e555c271ad504b88ac00000000",
        verifyFlags: "DERSIG,LOW_S,STRICTENC"
    ),

    // The following is a tweaked form of 23b397edccd3740a74adb603c9756370fafcde9bcc4483eb271ecad09a94dd63
    // It is an OP_CHECKMULTISIG with an arbitrary extra byte stuffed into the signature at pos length - 2
    // The dummy byte is fine however, so the NULLDUMMY flag should be happy
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "60a20bd93aa49ab4b28d514ec10b06e1829ce6818ec06cd3aabd013ebcdc4bb1",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .constant(1),
                    .pushBytes(.init(hex: "04cc71eb30d653c0c3163990c47b976f3fb3f37cccdcbedb169a1dfef58bbfbfaff7d8a473e7e2e6d317b87bafe8bde97e3cf8f065dec022b51d11fcdd0d348ac4")!),
                    .pushBytes(.init(hex: "0461cbdcc5409fb4b4d42b51d33381354d80e550078cb532a34bfa2fcfdeb7d76519aecc62770f5b0e4ef8551946d8a540911abe3e7854a26f39f58b25c15342af")!),
                    .constant(2),
                    .checkMultiSig
                ]
            )
        ],
        serializedTransaction: "0100000001b14bdcbc3e01bdaad36cc08e81e69c82e1060bc14e518db2b49aa43ad90ba260000000004a0048304402203f16c6f40162ab686621ef3000b04e75418a0c0cb2d8aebeac894ae360ac1e780220ddc15ecdfc3507ac48e1681a33eb60996631bf6bf5bc0a0682c4db743ce7ca2bab01ffffffff0140420f00000000001976a914660d4ef3a743e3e696ad990364e555c271ad504b88ac00000000",
        verifyFlags: "DERSIG,LOW_S,STRICTENC"
    ),

    // The following is a tweaked form of 23b397edccd3740a74adb603c9756370fafcde9bcc4483eb271ecad09a94dd63
    // It is an OP_CHECKMULTISIG with the dummy value set to something other than an empty string
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "60a20bd93aa49ab4b28d514ec10b06e1829ce6818ec06cd3aabd013ebcdc4bb1",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .constant(1),
                    .pushBytes(.init(hex: "04cc71eb30d653c0c3163990c47b976f3fb3f37cccdcbedb169a1dfef58bbfbfaff7d8a473e7e2e6d317b87bafe8bde97e3cf8f065dec022b51d11fcdd0d348ac4")!),
                    .pushBytes(.init(hex: "0461cbdcc5409fb4b4d42b51d33381354d80e550078cb532a34bfa2fcfdeb7d76519aecc62770f5b0e4ef8551946d8a540911abe3e7854a26f39f58b25c15342af")!),
                    .constant(2),
                    .checkMultiSig
                ]
            )
        ],
        serializedTransaction: "0100000001b14bdcbc3e01bdaad36cc08e81e69c82e1060bc14e518db2b49aa43ad90ba260000000004a01ff47304402203f16c6f40162ab686621ef3000b04e75418a0c0cb2d8aebeac894ae360ac1e780220ddc15ecdfc3507ac48e1681a33eb60996631bf6bf5bc0a0682c4db743ce7ca2b01ffffffff0140420f00000000001976a914660d4ef3a743e3e696ad990364e555c271ad504b88ac00000000",
        verifyFlags: "DERSIG,LOW_S,STRICTENC,NULLDUMMY"
    ),

    // As above, but using an OP_1
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "60a20bd93aa49ab4b28d514ec10b06e1829ce6818ec06cd3aabd013ebcdc4bb1",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .constant(1),
                    .pushBytes(.init(hex: "04cc71eb30d653c0c3163990c47b976f3fb3f37cccdcbedb169a1dfef58bbfbfaff7d8a473e7e2e6d317b87bafe8bde97e3cf8f065dec022b51d11fcdd0d348ac4")!),
                    .pushBytes(.init(hex: "0461cbdcc5409fb4b4d42b51d33381354d80e550078cb532a34bfa2fcfdeb7d76519aecc62770f5b0e4ef8551946d8a540911abe3e7854a26f39f58b25c15342af")!),
                    .constant(2),
                    .checkMultiSig
                ]
            )
        ],
        serializedTransaction: "0100000001b14bdcbc3e01bdaad36cc08e81e69c82e1060bc14e518db2b49aa43ad90ba26000000000495147304402203f16c6f40162ab686621ef3000b04e75418a0c0cb2d8aebeac894ae360ac1e780220ddc15ecdfc3507ac48e1681a33eb60996631bf6bf5bc0a0682c4db743ce7ca2b01ffffffff0140420f00000000001976a914660d4ef3a743e3e696ad990364e555c271ad504b88ac00000000",
        verifyFlags: "DERSIG,LOW_S,STRICTENC,NULLDUMMY"
    ),

    // As above, but using an OP_1NEGATE
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "60a20bd93aa49ab4b28d514ec10b06e1829ce6818ec06cd3aabd013ebcdc4bb1",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .constant(1),
                    .pushBytes(.init(hex: "04cc71eb30d653c0c3163990c47b976f3fb3f37cccdcbedb169a1dfef58bbfbfaff7d8a473e7e2e6d317b87bafe8bde97e3cf8f065dec022b51d11fcdd0d348ac4")!),
                    .pushBytes(.init(hex: "0461cbdcc5409fb4b4d42b51d33381354d80e550078cb532a34bfa2fcfdeb7d76519aecc62770f5b0e4ef8551946d8a540911abe3e7854a26f39f58b25c15342af")!),
                    .constant(2),
                    .checkMultiSig
                ]
            )
        ],
        serializedTransaction: "0100000001b14bdcbc3e01bdaad36cc08e81e69c82e1060bc14e518db2b49aa43ad90ba26000000000494f47304402203f16c6f40162ab686621ef3000b04e75418a0c0cb2d8aebeac894ae360ac1e780220ddc15ecdfc3507ac48e1681a33eb60996631bf6bf5bc0a0682c4db743ce7ca2b01ffffffff0140420f00000000001976a914660d4ef3a743e3e696ad990364e555c271ad504b88ac00000000",
        verifyFlags: "DERSIG,LOW_S,STRICTENC,NULLDUMMY"
    ),

    // The following is c99c49da4c38af669dea436d3e73780dfdb6c1ecf9958baa52960e8baee30e73
    // It is of interest because it contains a 0-sequence as well as a signature of SIGHASH type 0 (which is not a real type)
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "406b2b06bcd34d3c8733e6b79f7a394c8a431fbf4ff5ac705c93f4076bb77602",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .dup,
                    .hash160,
                    .pushBytes(.init(hex: "dc44b1164188067c3a32d4780f5996fa14a4f2d9")!),
                    .equalVerify,
                    .checkSig
                ]
            )
        ],
        serializedTransaction: "01000000010276b76b07f4935c70acf54fbf1f438a4c397a9fb7e633873c4dd3bc062b6b40000000008c493046022100d23459d03ed7e9511a47d13292d3430a04627de6235b6e51a40f9cd386f2abe3022100e7d25b080f0bb8d8d5f878bba7d54ad2fda650ea8d158a33ee3cbd11768191fd004104b0e2c879e4daf7b9ab68350228c159766676a14f5815084ba166432aab46198d4cca98fa3e9981d0a90b2effc514b76279476550ba3663fdcaff94c38420e9d5000000000100093d00000000001976a9149a7b0f3b80c6baaeedce0a0842553800f832ba1f88ac00000000",
        verifyFlags: "LOW_S,STRICTENC"
    ),

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
        verifyFlags: "NONE"
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
        verifyFlags: "CLEANSTACK,CONST_SCRIPTCODE"
    ),

    // The following is f7fdd091fa6d8f5e7a8c2458f5c38faffff2d3f1406b6e4fe2c99dcc0d2d1cbb
    // It caught a bug in the workaround for 23b397edccd3740a74adb603c9756370fafcde9bcc4483eb271ecad09a94dd63 in an overly simple implementation. In a signature, it contains an ASN1 integer which isn't strict-DER conformant due to being negative, which doesn't make sense in a signature. Before BIP66 activated, it was a valid signature. After it activated, it's not valid any more.
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "b464e85df2a238416f8bdae11d120add610380ea07f4ef19c5f9dfd472f96c3d",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .dup,
                    .hash160,
                    .pushBytes(.init(hex: "bef80ecf3a44500fda1bc92176e442891662aed2")!),
                    .equalVerify,
                    .checkSig
                ]
            ),
            .init(
                transactionIdentifier: "b7978cc96e59a8b13e0865d3f95657561a7f725be952438637475920bac9eb21",
                outputIndex: 1,
                amount: 0,
                scriptOperations: [
                    .dup,
                    .hash160,
                    .pushBytes(.init(hex: "bef80ecf3a44500fda1bc92176e442891662aed2")!),
                    .equalVerify,
                    .checkSig
                ]
            )
        ],
        serializedTransaction: "01000000023d6cf972d4dff9c519eff407ea800361dd0a121de1da8b6f4138a2f25de864b4000000008a4730440220ffda47bfc776bcd269da4832626ac332adfca6dd835e8ecd83cd1ebe7d709b0e022049cffa1cdc102a0b56e0e04913606c70af702a1149dc3b305ab9439288fee090014104266abb36d66eb4218a6dd31f09bb92cf3cfa803c7ea72c1fc80a50f919273e613f895b855fb7465ccbc8919ad1bd4a306c783f22cd3227327694c4fa4c1c439affffffff21ebc9ba20594737864352e95b727f1a565756f9d365083eb1a8596ec98c97b7010000008a4730440220503ff10e9f1e0de731407a4a245531c9ff17676eda461f8ceeb8c06049fa2c810220c008ac34694510298fa60b3f000df01caa244f165b727d4896eb84f81e46bcc4014104266abb36d66eb4218a6dd31f09bb92cf3cfa803c7ea72c1fc80a50f919273e613f895b855fb7465ccbc8919ad1bd4a306c783f22cd3227327694c4fa4c1c439affffffff01f0da5200000000001976a914857ccd42dded6df32949d4646dfa10a92458cfaa88ac00000000",
        verifyFlags: "DERSIG,LOW_S,STRICTENC"
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
        verifyFlags: "CLEANSTACK"
    ),


    // Tests for CheckTransaction()
    // MAX_MONEY output
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .hash160,
                    .pushBytes(Data(hex: "32afac281462b822adbec5094b8d4d337dd5bd6a")!),
                    .equal
                ]
            )
        ],
        serializedTransaction: "01000000010001000000000000000000000000000000000000000000000000000000000000000000006e493046022100e1eadba00d9296c743cb6ecc703fd9ddc9b3cd12906176a226ae4c18d6b00796022100a71aef7d2874deff681ba6080f1b278bac7bb99c61b08a85f4311970ffe7f63f012321030c0588dc44d92bdcbf8e72093466766fdc265ead8db64517b0c542275b70fffbacffffffff010040075af0750700015100000000",
        verifyFlags: "NONE" // LOW_S
    ),

    // MAX_MONEY output + 0 output
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .hash160,
                    .pushBytes(Data(hex: "b558cbf4930954aa6a344363a15668d7477ae716")!),
                    .equal
                ]
            )
        ],
        serializedTransaction: "01000000010001000000000000000000000000000000000000000000000000000000000000000000006d483045022027deccc14aa6668e78a8c9da3484fbcd4f9dcc9bb7d1b85146314b21b9ae4d86022100d0b43dece8cfb07348de0ca8bc5b86276fa88f7f2138381128b7c36ab2e42264012321029bb13463ddd5d2cc05da6e84e37536cb9525703cfd8f43afdb414988987a92f6acffffffff020040075af075070001510000000000000000015100000000",
        verifyFlags: "NONE" // LOW_S
    ),

    // Coinbase of size 2
    // Note the input is just required to make the tester happy
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000000",
                outputIndex: -1,
                amount: 0,
                scriptOperations: [
                    .constant(1)
                ]
            )
        ],
        serializedTransaction: "01000000010000000000000000000000000000000000000000000000000000000000000000ffffffff025151ffffffff010000000000000000015100000000",
        verifyFlags: "CLEANSTACK"
    ),

    // Coinbase of size 100
    // Note the input is just required to make the tester happy
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000000",
                outputIndex: -1,
                amount: 0,
                scriptOperations: [
                    .constant(1)
                ]
            )
        ],
        serializedTransaction: "01000000010000000000000000000000000000000000000000000000000000000000000000ffffffff6451515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151ffffffff010000000000000000015100000000",
        verifyFlags: "CLEANSTACK"
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
        verifyFlags: "NONE"
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
        verifyFlags: "LOW_S"
    ),

    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "444e00ed7840d41f20ecd9c11d3f91982326c731a02f3c05748414a4fa9e59be",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .constant(1),
                    .zero,
                    .pushBytes(.init(hex: "02136b04758b0b6e363e7a6fbe83aaf527a153db2b060d36cc29f7f8309ba6e458")!),
                    .constant(2),
                    .checkMultiSig
                ]
            )
        ],
        serializedTransaction: "0100000001be599efaa4148474053c2fa031c7262398913f1dc1d9ec201fd44078ed004e44000000004900473044022022b29706cb2ed9ef0cb3c97b72677ca2dfd7b4160f7b4beb3ba806aa856c401502202d1e52582412eba2ed474f1f437a427640306fd3838725fab173ade7fe4eae4a01ffffffff010100000000000000232103ac4bba7e7ca3e873eea49e08132ad30c7f03640b6539e9b59903cf14fd016bbbac00000000",
        verifyFlags: "NONE"
    ),

    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "e16abbe80bf30c080f63830c8dbf669deaef08957446e95940227d8c5e6db612",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .constant(1),
                    .pushBytes(.init(hex: "03905380c7013e36e6e19d305311c1b81fce6581f5ee1c86ef0627c68c9362fc9f")!),
                    .zero,
                    .constant(2),
                    .checkMultiSig
                ]
            )
        ],
        serializedTransaction: "010000000112b66d5e8c7d224059e946749508efea9d66bf8d0c83630f080cf30be8bb6ae100000000490047304402206ffe3f14caf38ad5c1544428e99da76ffa5455675ec8d9780fac215ca17953520220779502985e194d84baa36b9bd40a0dbd981163fa191eb884ae83fc5bd1c86b1101ffffffff010100000000000000232103905380c7013e36e6e19d305311c1b81fce6581f5ee1c86ef0627c68c9362fc9fac00000000",
        verifyFlags: "STRICTENC"
    ),

    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "ebbcf4bfce13292bd791d6a65a2a858d59adbf737e387e40370d4e64cc70efb0",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .constant(2),
                    .pushBytes(.init(hex: "033bcaa0a602f0d44cc9d5637c6e515b0471db514c020883830b7cefd73af04194")!),
                    .pushBytes(.init(hex: "03a88b326f8767f4f192ce252afe33c94d25ab1d24f27f159b3cb3aa691ffe1423")!),
                    .constant(2),
                    .checkMultiSig,
                    .not
                ]
            )
        ],
        serializedTransaction: "0100000001b0ef70cc644e0d37407e387e73bfad598d852a5aa6d691d72b2913cebff4bceb000000004a00473044022068cd4851fc7f9a892ab910df7a24e616f293bcb5c5fbdfbc304a194b26b60fba022078e6da13d8cb881a22939b952c24f88b97afd06b4c47a47d7f804c9a352a6d6d0100ffffffff0101000000000000002321033bcaa0a602f0d44cc9d5637c6e515b0471db514c020883830b7cefd73af04194ac00000000",
        verifyFlags: "NULLFAIL"
    ),

    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "ba4cd7ae2ad4d4d13ebfc8ab1d93a63e4a6563f25089a18bf0fc68f282aa88c1",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .constant(2),
                    .pushBytes(.init(hex: "037c615d761e71d38903609bf4f46847266edc2fb37532047d747ba47eaae5ffe1")!),
                    .pushBytes(.init(hex: "02edc823cd634f2c4033d94f5755207cb6b60c4b1f1f056ad7471c47de5f2e4d50")!),
                    .constant(2),
                    .checkMultiSig,
                    .not
                ]
            )
        ],
        serializedTransaction: "0100000001c188aa82f268fcf08ba18950f263654a3ea6931dabc8bf3ed1d4d42aaed74cba000000004b0000483045022100940378576e069aca261a6b26fb38344e4497ca6751bb10905c76bb689f4222b002204833806b014c26fd801727b792b1260003c55710f87c5adbd7a9cb57446dbc9801ffffffff0101000000000000002321037c615d761e71d38903609bf4f46847266edc2fb37532047d747ba47eaae5ffe1ac00000000",
        verifyFlags: "NULLFAIL"
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
        verifyFlags: "CONST_SCRIPTCODE,LOW_S"
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
        verifyFlags: "CONST_SCRIPTCODE,LOW_S"
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
        verifyFlags: "CONST_SCRIPTCODE,LOW_S"
    ),

]
