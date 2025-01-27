import Foundation
import Testing
import BitcoinCrypto
import BitcoinBase

struct BinaryCodableBaseTests {

    @Test func outpointRoundtrip() throws {
        let o = TxOutpoint.coinbase
        var counter = BinaryEncodingSizeCounter()
        counter.count(o)
        var encoder = BinaryEncoder(counter)
        encoder.encode(o)
        let data = encoder.data
        var decoder = BinaryDecoder(data)
        let o2: TxOutpoint = try decoder.decode()
        #expect(o == o2)
    }

    @Test func scriptOpRoundtrip() throws {
        let basicOp = ScriptOp.checkSig
        var counter = BinaryEncodingSizeCounter()
        counter.count(basicOp)
        var encoder = BinaryEncoder(counter)
        encoder.encode(basicOp)
        var data = encoder.data
        var decoder = BinaryDecoder(data)
        let basicOp2: ScriptOp = try decoder.decode()
        #expect(basicOp == basicOp2)

        let minPush = ScriptOp.pushBytes(.init([0, 1, 2]))
        counter = BinaryEncodingSizeCounter()
        counter.count(minPush)
        encoder = BinaryEncoder(counter)
        encoder.encode(minPush)
        data = encoder.data
        decoder = BinaryDecoder(data)
        let minPush2: ScriptOp = try decoder.decode()
        #expect(minPush == minPush2)
    }

    @Test func scriptRoundtrip() throws {
        let emptyScript = BitcoinScript.empty
        var counter = BinaryEncodingSizeCounter()
        counter.count(emptyScript)
        var encoder = BinaryEncoder(counter)
        encoder.encode(emptyScript)
        var data = encoder.data
        var decoder = BinaryDecoder(data)
        let emptyScript2: BitcoinScript = try decoder.decode()
        #expect(emptyScript == emptyScript2)

        let minPush: BitcoinScript = [ScriptOp.pushBytes(.init([0, 1, 2]))]
        counter = BinaryEncodingSizeCounter()
        counter.count(minPush)
        encoder = BinaryEncoder(counter)
        encoder.encode(minPush)
        data = encoder.data
        decoder = BinaryDecoder(data)
        let minPush2: BitcoinScript = try decoder.decode()
        #expect(minPush == minPush2)
    }

    @Test func scriptPrefixedRoundtrip() throws {
        let emptyScript = BitcoinScript.empty
        var counter = BinaryEncodingSizeCounter()
        emptyScript.encodingSizePrefixed(&counter)
        var encoder = BinaryEncoder(counter)
        emptyScript.encodePrefixed(to: &encoder)
        var data = encoder.data
        var decoder = BinaryDecoder(data)
        let emptyScript2 = try BitcoinScript(prefixedFrom: &decoder)
        #expect(emptyScript == emptyScript2)

        let minPush: BitcoinScript = [ScriptOp.pushBytes(.init([0, 1, 2]))]
        counter = BinaryEncodingSizeCounter()
        minPush.encodingSizePrefixed(&counter)
        encoder = BinaryEncoder(counter)
        minPush.encodePrefixed(to: &encoder)
        data = encoder.data
        decoder = BinaryDecoder(data)
        let minPush2 = try BitcoinScript(prefixedFrom: &decoder)
        #expect(minPush == minPush2)
    }

    @Test func sequenceRoundtrip() throws {
        let final = TxInSequence.final
        var counter = BinaryEncodingSizeCounter()
        counter.count(final)
        var encoder = BinaryEncoder(counter)
        encoder.encode(final)
        var data = encoder.data
        var decoder = BinaryDecoder(data)
        let final2: TxInSequence = try decoder.decode()
        #expect(final == final2)

        let maxBlocks = TxInSequence.maxLocktimeBlocks
        counter = BinaryEncodingSizeCounter()
        counter.count(maxBlocks)
        encoder = BinaryEncoder(counter)
        encoder.encode(maxBlocks)
        data = encoder.data
        decoder = BinaryDecoder(data)
        let maxBlocks2: TxInSequence = try decoder.decode()
        #expect(maxBlocks == maxBlocks2)
    }

    @Test func combinedRoundtrip() throws {
        let outpoint = TxOutpoint.coinbase
        let emptyScript = BitcoinScript.empty
        let sequence = TxInSequence.final
        var counter = BinaryEncodingSizeCounter()
        counter.count(outpoint)
        emptyScript.encodingSizePrefixed(&counter)
        counter.count(sequence)
        var encoder = BinaryEncoder(counter)
        encoder.encode(outpoint)
        emptyScript.encodePrefixed(to: &encoder)
        encoder.encode(sequence)
        let data = encoder.data
        var decoder = BinaryDecoder(data)
        let outpoint2: TxOutpoint = try decoder.decode()
        let emptyScript2 = try BitcoinScript(prefixedFrom: &decoder)
        let sequence2: TxInSequence = try decoder.decode()
        #expect(outpoint == outpoint2)
        #expect(emptyScript == emptyScript2)
        #expect(sequence == sequence2)
    }

    @Test func txInRoundtrip() throws {
        let i = TxIn(outpoint: .coinbase)
        var counter = BinaryEncodingSizeCounter()
        counter.count(i)
        var encoder = BinaryEncoder(counter)
        encoder.encode(i)
        let data = encoder.data
        var decoder = BinaryDecoder(data)
        let i2: TxIn = try decoder.decode()
        #expect(i == i2)
    }

    @Test("Outs", arguments: [
        TxOut(value: 420000000, script: .init([0x51, 0x20, 0x53, 0xa1, 0xf6, 0xe4, 0x54, 0xdf, 0x1a, 0xa2, 0x77, 0x6a, 0x28, 0x14, 0xa7, 0x21, 0x37, 0x2d, 0x62, 0x58, 0x05, 0x0d, 0xe3, 0x30, 0xb3, 0xc6, 0xd1, 0x0e, 0xe8, 0xf4, 0xe0, 0xdd, 0xa3, 0x43])),
        TxOut(value: 462000000, script: .init([0x51, 0x20, 0x14, 0x7c, 0x9c, 0x57, 0x13, 0x2f, 0x6e, 0x7e, 0xcd, 0xdb, 0xa9, 0x80, 0x0b, 0xb0, 0xc4, 0x44, 0x92, 0x51, 0xc9, 0x2a, 0x1e, 0x60, 0x37, 0x1e, 0xe7, 0x75, 0x57, 0xb6, 0x62, 0x0f, 0x3e, 0xa3])),
        TxOut(value: 294000000, script: .init([0x76, 0xa9, 0x14, 0x75, 0x1e, 0x76, 0xe8, 0x19, 0x91, 0x96, 0xd4, 0x54, 0x94, 0x1c, 0x45, 0xd1, 0xb3, 0xa3, 0x23, 0xf1, 0x43, 0x3b, 0xd6, 0x88, 0xac])),
        TxOut(value: 504000000, script: .init([0x51, 0x20, 0xe4, 0xd8, 0x10, 0xfd, 0x50, 0x58, 0x62, 0x74, 0xfa, 0xce, 0x62, 0xb8, 0xa8, 0x07, 0xeb, 0x97, 0x19, 0xce, 0xf4, 0x9c, 0x04, 0x17, 0x7c, 0xc6, 0xb7, 0x6a, 0x9a, 0x42, 0x51, 0xd5, 0x45, 0x0e])),
        TxOut(value: 630000000, script: .init([0x51, 0x20, 0x91, 0xb6, 0x4d, 0x53, 0x24, 0x72, 0x3a, 0x98, 0x51, 0x70, 0xe4, 0xdc, 0x5a, 0x0f, 0x84, 0xc0, 0x41, 0x80, 0x4f, 0x2c, 0xd1, 0x26, 0x60, 0xfa, 0x5d, 0xec, 0x09, 0xfc, 0x21, 0x78, 0x36, 0x05])),
        TxOut(value: 378000000, script: .init([0x00, 0x14, 0x7d, 0xd6, 0x55, 0x92, 0xd0, 0xab, 0x2f, 0xe0, 0xd0, 0x25, 0x7d, 0x57, 0x1a, 0xbf, 0x03, 0x2c, 0xd9, 0xdb, 0x93, 0xdc])),
        TxOut(value: 672000000, script: .init([0x51, 0x20, 0x75, 0x16, 0x9f, 0x40, 0x01, 0xaa, 0x68, 0xf1, 0x5b, 0xbe, 0xd2, 0x8b, 0x21, 0x8d, 0xf1, 0xd0, 0xa6, 0x2c, 0xbb, 0xcf, 0x11, 0x88, 0xc6, 0x66, 0x51, 0x10, 0xc2, 0x93, 0xc9, 0x07, 0xb8, 0x31])),
        TxOut(value: 546000000, script: .init([0x51, 0x20, 0x71, 0x24, 0x47, 0x20, 0x6d, 0x7a, 0x52, 0x38, 0xac, 0xc7, 0xff, 0x53, 0xfb, 0xe9, 0x4a, 0x3b, 0x64, 0x53, 0x9a, 0xd2, 0x91, 0xc7, 0xcd, 0xbc, 0x49, 0x0b, 0x75, 0x77, 0xe4, 0xb1, 0x7d, 0xf5])),
        TxOut(value: 588000000, script: .init([0x51, 0x20, 0x77, 0xe3, 0x0a, 0x55, 0x22, 0xdd, 0x9f, 0x89, 0x4c, 0x3f, 0x8b, 0x8b, 0xd4, 0xc4, 0xb2, 0xcf, 0x82, 0xca, 0x7d, 0xa8, 0xa3, 0xea, 0x6a, 0x23, 0x96, 0x55, 0xc3, 0x9c, 0x05, 0x0a, 0xb2, 0x20]))
    ])
    func txOutRoundtrip(_ txOut: TxOut) throws {
        var counter = BinaryEncodingSizeCounter()
        counter.count(txOut)
        var encoder = BinaryEncoder(counter)
        encoder.encode(txOut)
        let data = encoder.data
        var decoder = BinaryDecoder(data)
        let txOut2: TxOut = try decoder.decode()
        #expect(txOut == txOut2)
    }

    @Test func unparsableScript() throws {
        let scriptData = Data([0xac, 0x9a, 0x87, 0xf5, 0x59, 0x4b, 0xe2, 0x08, 0xf8, 0x53, 0x2d, 0xb3, 0x8c, 0xff, 0x67, 0x0c, 0x45, 0x0e, 0xd2, 0xfe, 0xa8, 0xfc, 0xde, 0xfc, 0xc9, 0xa6, 0x63, 0xf7, 0x8b, 0xab, 0x96, 0x2b])
        var decoder = BinaryDecoder(scriptData)
        let script: BitcoinScript = try decoder.decode()

        var counter = BinaryEncodingSizeCounter()
        counter.count(script)

        var encoder = BinaryEncoder(counter)
        encoder.encode(script)
        #expect(encoder.data == scriptData)

        let prefixedData = Data([0x20]) + scriptData
        decoder = BinaryDecoder(prefixedData)
        let script2 = try BitcoinScript(prefixedFrom: &decoder)
        #expect(script2.unparsable == script.unparsable)
        #expect(script2 == script)

        counter = BinaryEncodingSizeCounter()
        script2.encodingSizePrefixed(&counter)

        encoder = BinaryEncoder(counter)
        script2.encodePrefixed(to: &encoder)
        #expect(prefixedData == encoder.data)
    }

    @Test func txRoundtrip() throws {
        let tx = BitcoinTx(ins: [
            .init(outpoint: .coinbase, witness: .init([.init()])),
            .init(outpoint: .coinbase),
            .init(outpoint: .coinbase, witness: .init([.init()])),
        ], outs: [])
        let data = tx.binaryData
        let tx2 = try #require(try BitcoinTx(binaryData: data))
        #expect(tx == tx2)
    }
}
