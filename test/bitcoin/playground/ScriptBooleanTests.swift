import Testing
import Foundation
@testable import Bitcoin

struct ScriptBooleanTests {

    let zeroData = Data()
    let oneData = Data([1])

    @Test("Boolean false")
    func booleanFalse() {

        let negativeZero = Data([0x80])
        let falseValue = Data([0])
        let falseValue1 = Data([0, 0])
        let falseValue2 = Data([0, 0x80])
        let falseValue3 = Data([0, 0, 0x80])

        var b = ScriptBoolean(zeroData)
        #expect(!b.value)
        b = ScriptBoolean(negativeZero)
        #expect(!b.value)
        b = ScriptBoolean(falseValue)
        #expect(!b.value)
        b = ScriptBoolean(falseValue1)
        #expect(!b.value)
        b = ScriptBoolean(falseValue2)
        #expect(!b.value)
        b = ScriptBoolean(falseValue3)
        #expect(!b.value)
    }

    @Test("Boolean true")
    func booleanTrue() {
        let trueValue = Data([1])
        let trueValue1 = Data([0, 1])
        let trueValue2 = Data([1, 0])
        let trueValue3 = Data([0x80, 0])

        var b = ScriptBoolean(oneData)
        #expect(b.value)
        b = ScriptBoolean(trueValue)
        #expect(b.value)
        b = ScriptBoolean(trueValue1)
        #expect(b.value)
        b = ScriptBoolean(trueValue2)
        #expect(b.value)
        b = ScriptBoolean(trueValue3)
        #expect(b.value)
    }
}
