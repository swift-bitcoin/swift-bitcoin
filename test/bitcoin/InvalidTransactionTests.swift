import XCTest
@testable import Bitcoin

final class InvalidTransactionTests: XCTestCase {

    override class func setUp() {
        eccStart()
    }

    override class func tearDown() {
        eccStop()
    }

    func testInvalidTransactions() throws {
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
            if vector.excludedVerifyFlags == "BADTX" {
                XCTAssertThrowsError(try tx.check())
                return
            } else {
                XCTAssertNoThrow(try tx.check())
            }
            let result = tx.verify(previousOutputs: previousOutputs)
            XCTAssertFalse(result)
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
    let excludedVerifyFlags: String
}

fileprivate let testVectors: [TestVector] = [

    // Tests for CheckTransaction()
    // No outputs
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .hash160,
                    .pushBytes(Data(hex: "05ab9e14d983742513f0f451e105ffb4198d1dd4")!),
                    .equal
                ]
            )
        ],
        serializedTransaction: "01000000010001000000000000000000000000000000000000000000000000000000000000000000006d483045022100f16703104aab4e4088317c862daec83440242411b039d14280e03dd33b487ab802201318a7be236672c5c56083eb7a5a195bc57a40af7923ff8545016cd3b571e2a601232103c40e5d339df3f30bf753e7e04450ae4ef76c9e45587d1d993bdc4cd06f0651c7acffffffff0000000000",
        excludedVerifyFlags: "BADTX"
    ),

    // Negative output
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .hash160,
                    .pushBytes(Data(hex: "ae609aca8061d77c5e111f6bb62501a6bbe2bfdb")!),
                    .equal
                ]
            )
        ],
        serializedTransaction: "01000000010001000000000000000000000000000000000000000000000000000000000000000000006d4830450220063222cbb128731fc09de0d7323746539166544d6c1df84d867ccea84bcc8903022100bf568e8552844de664cd41648a031554327aa8844af34b4f27397c65b92c04de0123210243ec37dee0e2e053a9c976f43147e79bc7d9dc606ea51010af1ac80db6b069e1acffffffff01ffffffffffffffff015100000000",
        excludedVerifyFlags: "BADTX"
    ),

    // MAX_MONEY + 1 output
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
        serializedTransaction: "01000000010001000000000000000000000000000000000000000000000000000000000000000000006e493046022100e1eadba00d9296c743cb6ecc703fd9ddc9b3cd12906176a226ae4c18d6b00796022100a71aef7d2874deff681ba6080f1b278bac7bb99c61b08a85f4311970ffe7f63f012321030c0588dc44d92bdcbf8e72093466766fdc265ead8db64517b0c542275b70fffbacffffffff010140075af0750700015100000000",
        excludedVerifyFlags: "BADTX"
    ),

    // MAX_MONEY output + 1 output
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
        serializedTransaction: "01000000010001000000000000000000000000000000000000000000000000000000000000000000006d483045022027deccc14aa6668e78a8c9da3484fbcd4f9dcc9bb7d1b85146314b21b9ae4d86022100d0b43dece8cfb07348de0ca8bc5b86276fa88f7f2138381128b7c36ab2e42264012321029bb13463ddd5d2cc05da6e84e37536cb9525703cfd8f43afdb414988987a92f6acffffffff020040075af075070001510001000000000000015100000000",
        excludedVerifyFlags: "BADTX"
    ),

    // Duplicate inputs
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .hash160,
                    .pushBytes(Data(hex: "236d0639db62b0773fd8ac34dc85ae19e9aba80a")!),
                    .equal
                ]
            )
        ],
        serializedTransaction: "01000000020001000000000000000000000000000000000000000000000000000000000000000000006c47304402204bb1197053d0d7799bf1b30cd503c44b58d6240cccbdc85b6fe76d087980208f02204beeed78200178ffc6c74237bb74b3f276bbb4098b5605d814304fe128bf1431012321039e8815e15952a7c3fada1905f8cf55419837133bd7756c0ef14fc8dfe50c0deaacffffffff0001000000000000000000000000000000000000000000000000000000000000000000006c47304402202306489afef52a6f62e90bf750bbcdf40c06f5c6b138286e6b6b86176bb9341802200dba98486ea68380f47ebb19a7df173b99e6bc9c681d6ccf3bde31465d1f16b3012321039e8815e15952a7c3fada1905f8cf55419837133bd7756c0ef14fc8dfe50c0deaacffffffff010000000000000000015100000000",
        excludedVerifyFlags: "BADTX"
    ),

    // Coinbase of size 1
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
        serializedTransaction: "01000000010000000000000000000000000000000000000000000000000000000000000000ffffffff0151ffffffff010000000000000000015100000000",
        excludedVerifyFlags: "BADTX"
    ),

    // Coinbase of size 101
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
        serializedTransaction: "01000000010000000000000000000000000000000000000000000000000000000000000000ffffffff655151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151ffffffff010000000000000000015100000000",
        excludedVerifyFlags: "BADTX"
    ),

    // Null txin, but without being a coinbase (because there are two inputs)
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000000",
                outputIndex: -1,
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
                    .constant(1)
                ]
            )
        ],
        serializedTransaction: "01000000020000000000000000000000000000000000000000000000000000000000000000ffffffff00ffffffff00010000000000000000000000000000000000000000000000000000000000000000000000ffffffff010000000000000000015100000000",
        excludedVerifyFlags: "BADTX"
    ),

    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .constant(1)
                ]
            ),
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000000",
                outputIndex: -1,
                amount: 0,
                scriptOperations: [
                    .constant(1)
                ]
            )
        ],
        serializedTransaction: "010000000200010000000000000000000000000000000000000000000000000000000000000000000000ffffffff0000000000000000000000000000000000000000000000000000000000000000ffffffff00ffffffff010000000000000000015100000000",
        excludedVerifyFlags: "BADTX"
    ),
]
