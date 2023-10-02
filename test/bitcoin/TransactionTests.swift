import XCTest
@testable import Bitcoin

final class TransactionTests: XCTestCase {
    func testTransaction() throws {
        // A coinbase transaction
        _ = Transaction(
            version: .v1,
            locktime: .init(0),
            inputs: [
                .init(
                    outpoint: .init(
                        transaction: String(repeating: "0", count: 64),
                        output: 0xffffffff
                    ),
                    sequence: .init(0xffffffff),
                    script: .init([
                        0x05, // OP_PUSHBYTES_5
                        0x68, 0x65, 0x6c, 0x6c, 0x6f, // hello
                    ])
                )
            ],
            outputs: [
                .init(
                    value: 5_000_000_000, // 50 BTC
                    script: .init([
                        0x6a, // OP_RETURN
                        0x62, 0x79, 0x65 // bye
                    ])
                )
            ])
    }
}
