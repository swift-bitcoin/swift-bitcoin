import Testing
import Foundation
@testable import BitcoinBase

struct ScriptNumTests {

    let zeroData = Data()
    let oneData = Data([1])
    let minusOneData = Data([0b10000001])
    let oneByteMinData = Data([0xff]) // -127
    let oneByteMaxData = Data([127])
    let twoByteMinData = Data([0xff, 0xff])
    let twoByteMaxData = Data([0xff, 0x7f])
    let threeByteMinData = Data([0xff, 0xff, 0xff])
    let threeByteMaxData = Data([0xff, 0xff, 0x7f])
    let fourByteMinData = Data([0xff, 0xff, 0xff, 0xff])
    let fourByteMaxData = Data([0xff, 0xff, 0xff, 0x7f])
    let fiveByteMinData = Data([0xff, 0xff, 0xff, 0xff, 0xff])
    let fiveByteMaxData = Data([0xff, 0xff, 0xff, 0xff, 0x7f])

    @Test("Data roundtrips")
    func dataRoundTrips() throws {
        // Zero (0)
        let zeroNum = try ScriptNum(zeroData)
        let zeroDataBack = zeroNum.binaryData
        #expect(zeroDataBack == zeroData)

        // One (1)
        let oneNum = try ScriptNum(oneData)
        let oneDataBack = oneNum.binaryData
        #expect(oneDataBack == oneData)

        // Minus one (-1)
        let minusOneNum = try ScriptNum(minusOneData)
        let minusOneDataBack = minusOneNum.binaryData
        #expect(minusOneDataBack == minusOneData)

        // 1-byte max (127)
        let maxNum = try ScriptNum(oneByteMaxData)
        let maxDataBack = maxNum.binaryData
        #expect(maxDataBack == oneByteMaxData)

        // 1-byte min (-127)
        let minNum = try ScriptNum(oneByteMinData)
        let minDataBack = minNum.binaryData
        #expect(minDataBack == oneByteMinData)

        // 2-byte max (0x7fff)
        let twoByteMaxNum = try ScriptNum(twoByteMaxData)
        let twoByteMaxDataBack = twoByteMaxNum.binaryData
        #expect(twoByteMaxDataBack == twoByteMaxData)

        // 2-byte min (0xffff)
        let twoByteMinNum = try ScriptNum(twoByteMinData)
        let twoByteMinDataBack = twoByteMinNum.binaryData
        #expect(twoByteMinDataBack == twoByteMinData)

        // 3-byte max (0x7fffff)
        let threeByteMaxNum = try ScriptNum(threeByteMaxData)
        let threeByteMaxDataBack = threeByteMaxNum.binaryData
        #expect(threeByteMaxDataBack == threeByteMaxData)

        // 3-byte min (0xffffff)
        let threeByteMinNum = try ScriptNum(threeByteMinData)
        let threeByteMinDataBack = threeByteMinNum.binaryData
        #expect(threeByteMinDataBack == threeByteMinData)

        // 4-byte max (0x7fffffff)
        let fourByteMaxNum = try ScriptNum(fourByteMaxData)
        let fourByteMaxDataBack = fourByteMaxNum.binaryData
        #expect(fourByteMaxDataBack == fourByteMaxData)

        // 4-byte min (0xffffffff)
        let fourByteMinNum = try ScriptNum(fourByteMinData)
        let fourByteMinDataBack = fourByteMinNum.binaryData
        #expect(fourByteMinDataBack == fourByteMinData)

        // 5-byte max (0x7fffffffff)
        let fiveByteMaxNum = try ScriptNum(fiveByteMaxData, extendedLength: true)
        let fiveByteMaxDataBack = fiveByteMaxNum.binaryData
        #expect(fiveByteMaxDataBack == fiveByteMaxData)

        // 5-byte min (0xffffffffff)
        let fiveByteMinNum = try ScriptNum(fiveByteMinData, extendedLength: true)
        let fiveByteMinDataBack = fiveByteMinNum.binaryData
        #expect(fiveByteMinDataBack == fiveByteMinData)
    }

    @Test("Adding")
    func adding() throws {
        var a = try ScriptNum(zeroData)
        var a2 = a
        var b = try ScriptNum(zeroData)
        try a.add(b)
        var dataBack = a.binaryData
        #expect(dataBack == zeroData)
        try b.add(a2)
        dataBack = b.binaryData
        #expect(dataBack == zeroData)

        a = try ScriptNum(oneByteMinData)
        a2 = a
        b = try ScriptNum(oneByteMaxData)
        try a.add(b)
        dataBack = a.binaryData
        #expect(dataBack == zeroData)
        try b.add(a2)
        dataBack = b.binaryData
        #expect(dataBack == zeroData)

        a = try ScriptNum(twoByteMinData)
        a2 = a
        b = try ScriptNum(twoByteMaxData)
        try a.add(b)
        dataBack = a.binaryData
        #expect(dataBack == zeroData)
        try b.add(a2)
        dataBack = b.binaryData
        #expect(dataBack == zeroData)

        a = try ScriptNum(threeByteMinData)
        a2 = a
        b = try ScriptNum(threeByteMaxData)
        try a.add(b)
        dataBack = a.binaryData
        #expect(dataBack == zeroData)
        try b.add(a2)
        dataBack = b.binaryData
        #expect(dataBack == zeroData)

        a = try ScriptNum(fourByteMinData)
        a2 = a
        b = try ScriptNum(fourByteMaxData)
        try a.add(b)
        dataBack = a.binaryData
        #expect(dataBack == zeroData)
        try b.add(a2)
        dataBack = b.binaryData
        #expect(dataBack == zeroData)

        a = try ScriptNum(fiveByteMinData, extendedLength: true)
        a2 = a
        b = try ScriptNum(fiveByteMaxData, extendedLength: true)
        try a.add(b)
        dataBack = a.binaryData
        #expect(dataBack == zeroData)
        try b.add(a2)
        dataBack = b.binaryData
        #expect(dataBack == zeroData)
    }

    @Test("Minimal Data")
    func minimalData() throws {
        var number: ScriptNum = .negativeOne

        let zero = Data([])
        number = try ScriptNum(zero)
        #expect(number == .zero)
        number = try ScriptNum(zero, minimal: true)
        #expect(number == .zero)

        let explicitZero = Data([0b00000000])
        number = try ScriptNum(explicitZero)
        #expect(number == .zero)
        #expect(throws: ScriptError.zeroPaddedNumber) {
            _ = try ScriptNum(explicitZero, minimal: true)
        }

        let zeroPaddedZero = Data([0b00000000, 0b00000000])
        number = try ScriptNum(zeroPaddedZero)
        #expect(number == .zero)
        #expect(throws: ScriptError.zeroPaddedNumber) {
            _ = try ScriptNum(zeroPaddedZero, minimal: true)
        }

        let doublePaddedZero = Data([0b00000000, 0b00000000, 0b00000000])
        number = try ScriptNum(doublePaddedZero)
        #expect(number == .zero)
        #expect(throws: ScriptError.zeroPaddedNumber) {
            _ = try ScriptNum(doublePaddedZero, minimal: true)
        }

        let negativeZero = Data([0b10000000])
        number = try ScriptNum(negativeZero)
        #expect(number == .zero)
        #expect(throws: ScriptError.negativeZero) {
            _ = try ScriptNum(negativeZero, minimal: true)
        }

        let negativeZeroPadded = Data([0b00000000, 0b10000000]) // Little endian
        number = try ScriptNum(negativeZeroPadded)
        #expect(number == .zero)
        #expect(throws: ScriptError.negativeZero) {
            _ = try ScriptNum(negativeZeroPadded, minimal: true)
        }

        let negativeZeroDoublePadded = Data([0b00000000, 0b00000000, 0b10000000])
        number = try ScriptNum(negativeZeroDoublePadded)
        #expect(number == .zero)
        #expect(throws: ScriptError.negativeZero) {
            _ = try ScriptNum(negativeZeroDoublePadded, minimal: true)
        }

        let negativeOne = Data([0b10000001])
        number = try ScriptNum(negativeOne)
        #expect(number == .negativeOne)
        number = try ScriptNum(negativeOne, minimal: true)
        #expect(number == .negativeOne)

        let negativeOnePadded = Data([0b00000001, 0b10000000])
        number = try ScriptNum(negativeOnePadded)
        #expect(number == .negativeOne)
        #expect(throws: ScriptError.zeroPaddedNumber) {
            _ = try ScriptNum(negativeOnePadded, minimal: true)
        }

        let negativeOneDoublePadded = Data([0b00000001, 0b00000000, 0b10000000])
        number = try ScriptNum(negativeOneDoublePadded)
        #expect(number == .negativeOne)
        #expect(throws: ScriptError.zeroPaddedNumber) {
            _ = try ScriptNum(negativeOneDoublePadded, minimal: true)
        }

        let minus127 = Data([0b11111111])
        number = try ScriptNum(minus127)
        #expect(number.value == -127)
        number = try ScriptNum(minus127, minimal: true)
        #expect(number.value == -127)

        let possitive255 = Data([0b11111111, 0b00000000])
        number = try ScriptNum(possitive255)
        #expect(number.value == 255)
        number = try ScriptNum(possitive255, minimal: true)
        #expect(number.value == 255)

        let possitive255Padded = Data([0b11111111, 0b00000000, 0b00000000])
        number = try ScriptNum(possitive255Padded)
        #expect(number.value == 255)
        #expect(throws: ScriptError.zeroPaddedNumber) {
            _ = try ScriptNum(possitive255Padded, minimal: true)
        }

        let maxBytesPadded = Data([0b00000000, 0b00000000, 0b00000000, 0b01000000, 0b00000000])
        number = try ScriptNum(maxBytesPadded, extendedLength: true)
        #expect(number.value == 0x40000000)
        #expect(throws: ScriptError.zeroPaddedNumber) {
            _ = try ScriptNum(maxBytesPadded, extendedLength: true, minimal: true)
        }

        let maxBytesPaddingOk = Data([0b00000000, 0b00000000, 0b00000000, 0b10000000, 0b00000000])
        number = try ScriptNum(maxBytesPaddingOk, extendedLength: true)
        #expect(number.value == 0x80000000)
        number = try ScriptNum(maxBytesPaddingOk, extendedLength: true, minimal: true)
        #expect(number.value == 0x80000000)
    }
}
