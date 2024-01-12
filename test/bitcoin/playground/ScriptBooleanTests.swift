import XCTest
@testable import Bitcoin

final class ScriptBooleanTests: XCTestCase {

    let zeroData = Data()
    let oneData = Data([1])

    func testFalse() {

        let negativeZero = Data([0x80])
        let falseValue = Data([0])
        let falseValue1 = Data([0, 0])
        let falseValue2 = Data([0, 0x80])
        let falseValue3 = Data([0, 0, 0x80])

        var b = ScriptBoolean(zeroData)
        XCTAssertFalse(b.value)
        b = ScriptBoolean(negativeZero)
        XCTAssertFalse(b.value)
        b = ScriptBoolean(falseValue)
        XCTAssertFalse(b.value)
        b = ScriptBoolean(falseValue1)
        XCTAssertFalse(b.value)
        b = ScriptBoolean(falseValue2)
        XCTAssertFalse(b.value)
        b = ScriptBoolean(falseValue3)
        XCTAssertFalse(b.value)
    }

    func testTrue() {
        let trueValue = Data([1])
        let trueValue1 = Data([0, 1])
        let trueValue2 = Data([1, 0])
        let trueValue3 = Data([0x80, 0])

        var b = ScriptBoolean(oneData)
        XCTAssert(b.value)
        b = ScriptBoolean(trueValue)
        XCTAssert(b.value)
        b = ScriptBoolean(trueValue1)
        XCTAssert(b.value)
        b = ScriptBoolean(trueValue2)
        XCTAssert(b.value)
        b = ScriptBoolean(trueValue3)
        XCTAssert(b.value)
    }
}
