import XCTest
@testable import Bitcoin

final class ScriptNumberTests: XCTestCase {

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

    func testDataRoundTrips() throws {
        // Zero (0)
        let zeroNum: ScriptNumber
        do {
            zeroNum = try ScriptNumber(zeroData)
        } catch {
            XCTFail()
            return
        }
        let zeroDataBack = zeroNum.data
        XCTAssertEqual(zeroDataBack, zeroData)

        // One (1)
        let oneNum = try ScriptNumber(oneData)
        let oneDataBack = oneNum.data
        XCTAssertEqual(oneDataBack, oneData)

        // Minus one (-1)
        let minusOneNum = try ScriptNumber(minusOneData)
        let minusOneDataBack = minusOneNum.data
        XCTAssertEqual(minusOneDataBack, minusOneData)

        // 1-byte max (127)
        let maxNum = try ScriptNumber(oneByteMaxData)
        let maxDataBack = maxNum.data
        XCTAssertEqual(maxDataBack, oneByteMaxData)

        // 1-byte min (-127)
        let minNum = try ScriptNumber(oneByteMinData)
        let minDataBack = minNum.data
        XCTAssertEqual(minDataBack, oneByteMinData)

        // 2-byte max (0x7fff)
        let twoByteMaxNum = try ScriptNumber(twoByteMaxData)
        let twoByteMaxDataBack = twoByteMaxNum.data
        XCTAssertEqual(twoByteMaxDataBack, twoByteMaxData)

        // 2-byte min (0xffff)
        let twoByteMinNum = try ScriptNumber(twoByteMinData)
        let twoByteMinDataBack = twoByteMinNum.data
        XCTAssertEqual(twoByteMinDataBack, twoByteMinData)

        // 3-byte max (0x7fffff)
        let threeByteMaxNum = try ScriptNumber(threeByteMaxData)
        let threeByteMaxDataBack = threeByteMaxNum.data
        XCTAssertEqual(threeByteMaxDataBack, threeByteMaxData)

        // 3-byte min (0xffffff)
        let threeByteMinNum = try ScriptNumber(threeByteMinData)
        let threeByteMinDataBack = threeByteMinNum.data
        XCTAssertEqual(threeByteMinDataBack, threeByteMinData)

        // 4-byte max (0x7fffffff)
        let fourByteMaxNum = try ScriptNumber(fourByteMaxData)
        let fourByteMaxDataBack = fourByteMaxNum.data
        XCTAssertEqual(fourByteMaxDataBack, fourByteMaxData)

        // 4-byte min (0xffffffff)
        let fourByteMinNum = try ScriptNumber(fourByteMinData)
        let fourByteMinDataBack = fourByteMinNum.data
        XCTAssertEqual(fourByteMinDataBack, fourByteMinData)

        // 5-byte max (0x7fffffffff)
        let fiveByteMaxNum = try ScriptNumber(fiveByteMaxData, extendedLength: true)
        let fiveByteMaxDataBack = fiveByteMaxNum.data
        XCTAssertEqual(fiveByteMaxDataBack, fiveByteMaxData)

        // 5-byte min (0xffffffffff)
        let fiveByteMinNum = try ScriptNumber(fiveByteMinData, extendedLength: true)
        let fiveByteMinDataBack = fiveByteMinNum.data
        XCTAssertEqual(fiveByteMinDataBack, fiveByteMinData)
    }

    func testAdd() throws {
        var a = try ScriptNumber(zeroData)
        var a2 = a
        var b = try ScriptNumber(zeroData)
        XCTAssertNoThrow(try a.add(b))
        var dataBack = a.data
        XCTAssertEqual(dataBack, zeroData)
        XCTAssertNoThrow(try b.add(a2))
        dataBack = b.data
        XCTAssertEqual(dataBack, zeroData)

        a = try ScriptNumber(oneByteMinData)
        a2 = a
        b = try ScriptNumber(oneByteMaxData)
        XCTAssertNoThrow(try a.add(b))
        dataBack = a.data
        XCTAssertEqual(dataBack, zeroData)
        XCTAssertNoThrow(try b.add(a2))
        dataBack = b.data
        XCTAssertEqual(dataBack, zeroData)

        a = try ScriptNumber(twoByteMinData)
        a2 = a
        b = try ScriptNumber(twoByteMaxData)
        XCTAssertNoThrow(try a.add(b))
        dataBack = a.data
        XCTAssertEqual(dataBack, zeroData)
        XCTAssertNoThrow(try b.add(a2))
        dataBack = b.data
        XCTAssertEqual(dataBack, zeroData)

        a = try ScriptNumber(threeByteMinData)
        a2 = a
        b = try ScriptNumber(threeByteMaxData)
        XCTAssertNoThrow(try a.add(b))
        dataBack = a.data
        XCTAssertEqual(dataBack, zeroData)
        XCTAssertNoThrow(try b.add(a2))
        dataBack = b.data
        XCTAssertEqual(dataBack, zeroData)

        a = try ScriptNumber(fourByteMinData)
        a2 = a
        b = try ScriptNumber(fourByteMaxData)
        XCTAssertNoThrow(try a.add(b))
        dataBack = a.data
        XCTAssertEqual(dataBack, zeroData)
        XCTAssertNoThrow(try b.add(a2))
        dataBack = b.data
        XCTAssertEqual(dataBack, zeroData)

        a = try ScriptNumber(fiveByteMinData, extendedLength: true)
        a2 = a
        b = try ScriptNumber(fiveByteMaxData, extendedLength: true)
        XCTAssertNoThrow(try a.add(b))
        dataBack = a.data
        XCTAssertEqual(dataBack, zeroData)
        XCTAssertNoThrow(try b.add(a2))
        dataBack = b.data
        XCTAssertEqual(dataBack, zeroData)
    }

    func testMinimalData() throws {
        var number: ScriptNumber = .negativeOne

        let zero = Data([])
        XCTAssertNoThrow(number = try ScriptNumber(zero))
        XCTAssertEqual(number, .zero)
        XCTAssertNoThrow(number = try ScriptNumber(zero, minimal: true))
        XCTAssertEqual(number, .zero)

        let explicitZero = Data([0b00000000])
        XCTAssertNoThrow(number = try ScriptNumber(explicitZero))
        XCTAssertEqual(number, .zero)
        do {
            _ = try ScriptNumber(explicitZero, minimal: true)
        } catch ScriptError.zeroPaddedNumber {
            // Expected
        } catch {
            // Wrong error
            XCTFail()
        }

        let zeroPaddedZero = Data([0b00000000, 0b00000000])
        XCTAssertNoThrow(number = try ScriptNumber(zeroPaddedZero))
        XCTAssertEqual(number, .zero)
        do {
            _ = try ScriptNumber(zeroPaddedZero, minimal: true)
        } catch ScriptError.zeroPaddedNumber {
            // Expected
        } catch {
            // Wrong error
            XCTFail()
        }

        let doublePaddedZero = Data([0b00000000, 0b00000000, 0b00000000])
        XCTAssertNoThrow(number = try ScriptNumber(doublePaddedZero))
        XCTAssertEqual(number, .zero)
        do {
            _ = try ScriptNumber(doublePaddedZero, minimal: true)
        } catch ScriptError.zeroPaddedNumber {
            // Expected
        } catch {
            // Wrong error
            XCTFail()
        }

        let negativeZero = Data([0b10000000])
        XCTAssertNoThrow(number = try ScriptNumber(negativeZero))
        XCTAssertEqual(number, .zero)
        do {
            _ = try ScriptNumber(negativeZero, minimal: true)
        } catch ScriptError.negativeZero {
            // Expected
        } catch {
            // Wrong error
            XCTFail()
        }

        let negativeZeroPadded = Data([0b00000000, 0b10000000]) // Little endian
        XCTAssertNoThrow(number = try ScriptNumber(negativeZeroPadded))
        XCTAssertEqual(number, .zero)
        do {
            _ = try ScriptNumber(negativeZeroPadded, minimal: true)
        } catch ScriptError.negativeZero {
            // Expected
        } catch {
            // Wrong error
            XCTFail()
        }

        let negativeZeroDoublePadded = Data([0b00000000, 0b00000000, 0b10000000])
        XCTAssertNoThrow(number = try ScriptNumber(negativeZeroDoublePadded))
        XCTAssertEqual(number, .zero)
        do {
            _ = try ScriptNumber(negativeZeroDoublePadded, minimal: true)
        } catch ScriptError.negativeZero {
            // Expected
        } catch {
            // Wrong error
            XCTFail()
        }

        let negativeOne = Data([0b10000001])
        XCTAssertNoThrow(number = try ScriptNumber(negativeOne))
        XCTAssertEqual(number, .negativeOne)
        XCTAssertNoThrow(number = try ScriptNumber(negativeOne, minimal: true))
        XCTAssertEqual(number, .negativeOne)

        let negativeOnePadded = Data([0b00000001, 0b10000000])
        XCTAssertNoThrow(number = try ScriptNumber(negativeOnePadded))
        XCTAssertEqual(number, .negativeOne)
        do {
            _ = try ScriptNumber(negativeOnePadded, minimal: true)
        } catch ScriptError.zeroPaddedNumber {
            // Expected
        } catch {
            // Wrong error
            XCTFail()
        }

        let negativeOneDoublePadded = Data([0b00000001, 0b00000000, 0b10000000])
        XCTAssertNoThrow(number = try ScriptNumber(negativeOneDoublePadded))
        XCTAssertEqual(number, .negativeOne)
        do {
            _ = try ScriptNumber(negativeOneDoublePadded, minimal: true)
        } catch ScriptError.zeroPaddedNumber {
            // Expected
        } catch {
            // Wrong error
            XCTFail()
        }

        let minus127 = Data([0b11111111])
        XCTAssertNoThrow(number = try ScriptNumber(minus127))
        XCTAssertEqual(number.value, -127)
        XCTAssertNoThrow(number = try ScriptNumber(minus127, minimal: true))
        XCTAssertEqual(number.value, -127)

        let possitive255 = Data([0b11111111, 0b00000000])
        XCTAssertNoThrow(number = try ScriptNumber(possitive255))
        XCTAssertEqual(number.value, 255)
        XCTAssertNoThrow(number = try ScriptNumber(possitive255, minimal: true))
        XCTAssertEqual(number.value, 255)

        let possitive255Padded = Data([0b11111111, 0b00000000, 0b00000000])
        XCTAssertNoThrow(number = try ScriptNumber(possitive255Padded))
        XCTAssertEqual(number.value, 255)
        do {
            _ = try ScriptNumber(possitive255Padded, minimal: true)
        } catch ScriptError.zeroPaddedNumber {
            // Expected
        } catch {
            // Wrong error
            XCTFail()
        }

        let maxBytesPadded = Data([0b00000000, 0b00000000, 0b00000000, 0b01000000, 0b00000000])
        XCTAssertNoThrow(number = try ScriptNumber(maxBytesPadded, extendedLength: true))
        XCTAssertEqual(number.value, 0x40000000)
        do {
            _ = try ScriptNumber(maxBytesPadded, extendedLength: true, minimal: true)
        } catch ScriptError.zeroPaddedNumber {
            // Expected
        } catch {
            // Wrong error
            XCTFail()
        }

        let maxBytesPaddingOk = Data([0b00000000, 0b00000000, 0b00000000, 0b10000000, 0b00000000])
        XCTAssertNoThrow(number = try ScriptNumber(maxBytesPaddingOk, extendedLength: true))
        XCTAssertEqual(number.value, 0x80000000)
        XCTAssertNoThrow(number = try ScriptNumber(maxBytesPaddingOk, extendedLength: true, minimal: true))
        XCTAssertEqual(number.value, 0x80000000)

    }
}
