import Testing
import Foundation
import BitcoinPSBT
import BitcoinBase

struct PartiallySignedTxTests {

    @Test func basicRoundtrip() throws {
        let fund0 = BitcoinTx(ins: [.init(outpoint: .coinbase)], outs: [.init(value: 3)])
        let fund1 = BitcoinTx(ins: [.init(outpoint: .coinbase)], outs: [.init(value: 2), .init(value: 5)])
        let tx = BitcoinTx(ins: [
            .init(outpoint: fund0.outpoint(0)),
            .init(outpoint: fund1.outpoint(1))
        ], outs: [
            .init(value: 1),
            .init(value: 2),
            .init(value: 4)
        ])
        let psbt = try PartiallySignedTx(tx, ins: [
            .init(
                prevoutTx: fund0
            ), .init(
                prevoutTx: fund1
            )
        ], outs: [
            .init(), .init(), .init()
        ])
        let psbtData = psbt.binaryData
        let psbt2 = try PartiallySignedTx(binaryData: psbtData)
        #expect(psbt == psbt2)
    }

    @Test func proprietary() throws {
        let proprietaryInfo = [
            "satoshi".data(using: .utf8)! : [
                ProprietaryKey(type: 0, data: .init([0])) : Data([0, 0, 0]),
                ProprietaryKey(type: .max, data: .init([1, 2, 3])) : Data([1, 2, 3, 4, 5, 6])
            ],
            "hal".data(using: .utf8)! : [
                ProprietaryKey(type: 101, data: .init([0, 0 , 0])) : Data([1, 0, 1]),
                ProprietaryKey(type: 1, data: .init([1, 1, 1, 1])) : Data([2, 3, 4, 5, 6])
            ]
        ]
        let fund0 = BitcoinTx(ins: [.init(outpoint: .coinbase)], outs: [.init(value: 3)])
        let fund1 = BitcoinTx(ins: [.init(outpoint: .coinbase)], outs: [.init(value: 2), .init(value: 5)])
        let tx = BitcoinTx(ins: [
            .init(outpoint: fund0.outpoint(0)),
            .init(outpoint: fund1.outpoint(1))
        ], outs: [
            .init(value: 1),
            .init(value: 2),
            .init(value: 4)
        ])
        let psbt = try PartiallySignedTx(tx, proprietaryInfo: proprietaryInfo, ins: [
            .init(
                prevoutTx: fund0, proprietaryInfo: proprietaryInfo
            ), .init(
                prevoutTx: fund1, proprietaryInfo: proprietaryInfo
            )
        ], outs: [
            .init(proprietaryInfo: proprietaryInfo), .init(proprietaryInfo: proprietaryInfo), .init(proprietaryInfo: proprietaryInfo)
        ])
        let psbtData = psbt.binaryData
        let psbt2 = try PartiallySignedTx(binaryData: psbtData)
        #expect(psbt == psbt2)
    }
}
