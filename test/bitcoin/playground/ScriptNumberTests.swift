import Testing
import Foundation
@testable import Bitcoin

struct ScriptNumberTests {

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
        let zeroNum = try ScriptNumber(zeroData)
        let zeroDataBack = zeroNum.data
        #expect(zeroDataBack == zeroData)

        // One (1)
        let oneNum = try ScriptNumber(oneData)
        let oneDataBack = oneNum.data
        #expect(oneDataBack == oneData)

        // Minus one (-1)
        let minusOneNum = try ScriptNumber(minusOneData)
        let minusOneDataBack = minusOneNum.data
        #expect(minusOneDataBack == minusOneData)

        // 1-byte max (127)
        let maxNum = try ScriptNumber(oneByteMaxData)
        let maxDataBack = maxNum.data
        #expect(maxDataBack == oneByteMaxData)

        // 1-byte min (-127)
        let minNum = try ScriptNumber(oneByteMinData)
        let minDataBack = minNum.data
        #expect(minDataBack == oneByteMinData)

        // 2-byte max (0x7fff)
        let twoByteMaxNum = try ScriptNumber(twoByteMaxData)
        let twoByteMaxDataBack = twoByteMaxNum.data
        #expect(twoByteMaxDataBack == twoByteMaxData)

        // 2-byte min (0xffff)
        let twoByteMinNum = try ScriptNumber(twoByteMinData)
        let twoByteMinDataBack = twoByteMinNum.data
        #expect(twoByteMinDataBack == twoByteMinData)

        // 3-byte max (0x7fffff)
        let threeByteMaxNum = try ScriptNumber(threeByteMaxData)
        let threeByteMaxDataBack = threeByteMaxNum.data
        #expect(threeByteMaxDataBack == threeByteMaxData)

        // 3-byte min (0xffffff)
        let threeByteMinNum = try ScriptNumber(threeByteMinData)
        let threeByteMinDataBack = threeByteMinNum.data
        #expect(threeByteMinDataBack == threeByteMinData)

        // 4-byte max (0x7fffffff)
        let fourByteMaxNum = try ScriptNumber(fourByteMaxData)
        let fourByteMaxDataBack = fourByteMaxNum.data
        #expect(fourByteMaxDataBack == fourByteMaxData)

        // 4-byte min (0xffffffff)
        let fourByteMinNum = try ScriptNumber(fourByteMinData)
        let fourByteMinDataBack = fourByteMinNum.data
        #expect(fourByteMinDataBack == fourByteMinData)

        // 5-byte max (0x7fffffffff)
        let fiveByteMaxNum = try ScriptNumber(fiveByteMaxData, extendedLength: true)
        let fiveByteMaxDataBack = fiveByteMaxNum.data
        #expect(fiveByteMaxDataBack == fiveByteMaxData)

        // 5-byte min (0xffffffffff)
        let fiveByteMinNum = try ScriptNumber(fiveByteMinData, extendedLength: true)
        let fiveByteMinDataBack = fiveByteMinNum.data
        #expect(fiveByteMinDataBack == fiveByteMinData)
    }

    @Test("Adding")
    func adding() throws {
        var a = try ScriptNumber(zeroData)
        var a2 = a
        var b = try ScriptNumber(zeroData)
        try a.add(b)
        var dataBack = a.data
        #expect(dataBack == zeroData)
        try b.add(a2)
        dataBack = b.data
        #expect(dataBack == zeroData)

        a = try ScriptNumber(oneByteMinData)
        a2 = a
        b = try ScriptNumber(oneByteMaxData)
        try a.add(b)
        dataBack = a.data
        #expect(dataBack == zeroData)
        try b.add(a2)
        dataBack = b.data
        #expect(dataBack == zeroData)

        a = try ScriptNumber(twoByteMinData)
        a2 = a
        b = try ScriptNumber(twoByteMaxData)
        try a.add(b)
        dataBack = a.data
        #expect(dataBack == zeroData)
        try b.add(a2)
        dataBack = b.data
        #expect(dataBack == zeroData)

        a = try ScriptNumber(threeByteMinData)
        a2 = a
        b = try ScriptNumber(threeByteMaxData)
        try a.add(b)
        dataBack = a.data
        #expect(dataBack == zeroData)
        try b.add(a2)
        dataBack = b.data
        #expect(dataBack == zeroData)

        a = try ScriptNumber(fourByteMinData)
        a2 = a
        b = try ScriptNumber(fourByteMaxData)
        try a.add(b)
        dataBack = a.data
        #expect(dataBack == zeroData)
        try b.add(a2)
        dataBack = b.data
        #expect(dataBack == zeroData)

        a = try ScriptNumber(fiveByteMinData, extendedLength: true)
        a2 = a
        b = try ScriptNumber(fiveByteMaxData, extendedLength: true)
        try a.add(b)
        dataBack = a.data
        #expect(dataBack == zeroData)
        try b.add(a2)
        dataBack = b.data
        #expect(dataBack == zeroData)
    }

    @Test("Minimal Data")
    func minimalData() throws {
        var number: ScriptNumber = .negativeOne

        let zero = Data([])
        number = try ScriptNumber(zero)
        #expect(number == .zero)
        number = try ScriptNumber(zero, minimal: true)
        #expect(number == .zero)

        let explicitZero = Data([0b00000000])
        number = try ScriptNumber(explicitZero)
        #expect(number == .zero)
        #expect(throws: ScriptError.zeroPaddedNumber) {
            _ = try ScriptNumber(explicitZero, minimal: true)
        }

        let zeroPaddedZero = Data([0b00000000, 0b00000000])
        number = try ScriptNumber(zeroPaddedZero)
        #expect(number == .zero)
        #expect(throws: ScriptError.zeroPaddedNumber) {
            _ = try ScriptNumber(zeroPaddedZero, minimal: true)
        }

        let doublePaddedZero = Data([0b00000000, 0b00000000, 0b00000000])
        number = try ScriptNumber(doublePaddedZero)
        #expect(number == .zero)
        #expect(throws: ScriptError.zeroPaddedNumber) {
            _ = try ScriptNumber(doublePaddedZero, minimal: true)
        }

        let negativeZero = Data([0b10000000])
        number = try ScriptNumber(negativeZero)
        #expect(number == .zero)
        #expect(throws: ScriptError.negativeZero) {
            _ = try ScriptNumber(negativeZero, minimal: true)
        }

        let negativeZeroPadded = Data([0b00000000, 0b10000000]) // Little endian
        number = try ScriptNumber(negativeZeroPadded)
        #expect(number == .zero)
        #expect(throws: ScriptError.negativeZero) {
            _ = try ScriptNumber(negativeZeroPadded, minimal: true)
        }

        let negativeZeroDoublePadded = Data([0b00000000, 0b00000000, 0b10000000])
        number = try ScriptNumber(negativeZeroDoublePadded)
        #expect(number == .zero)
        #expect(throws: ScriptError.negativeZero) {
            _ = try ScriptNumber(negativeZeroDoublePadded, minimal: true)
        }

        let negativeOne = Data([0b10000001])
        number = try ScriptNumber(negativeOne)
        #expect(number == .negativeOne)
        number = try ScriptNumber(negativeOne, minimal: true)
        #expect(number == .negativeOne)

        let negativeOnePadded = Data([0b00000001, 0b10000000])
        number = try ScriptNumber(negativeOnePadded)
        #expect(number == .negativeOne)
        #expect(throws: ScriptError.zeroPaddedNumber) {
            _ = try ScriptNumber(negativeOnePadded, minimal: true)
        }

        let negativeOneDoublePadded = Data([0b00000001, 0b00000000, 0b10000000])
        number = try ScriptNumber(negativeOneDoublePadded)
        #expect(number == .negativeOne)
        #expect(throws: ScriptError.zeroPaddedNumber) {
            _ = try ScriptNumber(negativeOneDoublePadded, minimal: true)
        }

        let minus127 = Data([0b11111111])
        number = try ScriptNumber(minus127)
        #expect(number.value == -127)
        number = try ScriptNumber(minus127, minimal: true)
        #expect(number.value == -127)

        let possitive255 = Data([0b11111111, 0b00000000])
        number = try ScriptNumber(possitive255)
        #expect(number.value == 255)
        number = try ScriptNumber(possitive255, minimal: true)
        #expect(number.value == 255)

        let possitive255Padded = Data([0b11111111, 0b00000000, 0b00000000])
        number = try ScriptNumber(possitive255Padded)
        #expect(number.value == 255)
        #expect(throws: ScriptError.zeroPaddedNumber) {
            _ = try ScriptNumber(possitive255Padded, minimal: true)
        }

        let maxBytesPadded = Data([0b00000000, 0b00000000, 0b00000000, 0b01000000, 0b00000000])
        number = try ScriptNumber(maxBytesPadded, extendedLength: true)
        #expect(number.value == 0x40000000)
        #expect(throws: ScriptError.zeroPaddedNumber) {
            _ = try ScriptNumber(maxBytesPadded, extendedLength: true, minimal: true)
        }

        let maxBytesPaddingOk = Data([0b00000000, 0b00000000, 0b00000000, 0b10000000, 0b00000000])
        number = try ScriptNumber(maxBytesPaddingOk, extendedLength: true)
        #expect(number.value == 0x80000000)
        number = try ScriptNumber(maxBytesPaddingOk, extendedLength: true, minimal: true)
        #expect(number.value == 0x80000000)
    }
}
