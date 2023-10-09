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
}
