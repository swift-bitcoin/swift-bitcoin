import Foundation
import Testing

@testable import BitcoinBase

struct ScriptBoolTests {
    let zeroData = Data()
    let oneData = Data([1])

    @Test("Boolean false")
    func booleanFalse() {
        let negativeZero = Data([0x80])
        let falseValue = Data([0])
        let falseValue1 = Data([0, 0])
        let falseValue2 = Data([0, 0x80])
        let falseValue3 = Data([0, 0, 0x80])

        var b = ScriptBool(zeroData)
        #expect(!b.value)
        b = ScriptBool(negativeZero)
        #expect(!b.value)
        b = ScriptBool(falseValue)
        #expect(!b.value)
        b = ScriptBool(falseValue1)
        #expect(!b.value)
        b = ScriptBool(falseValue2)
        #expect(!b.value)
        b = ScriptBool(falseValue3)
        #expect(!b.value)
    }

    @Test("Boolean true")
    func booleanTrue() {
        let trueValue = Data([1])
        let trueValue1 = Data([0, 1])
        let trueValue2 = Data([1, 0])
        let trueValue3 = Data([0x80, 0])

        var b = ScriptBool(oneData)
        #expect(b.value)
        b = ScriptBool(trueValue)
        #expect(b.value)
        b = ScriptBool(trueValue1)
        #expect(b.value)
        b = ScriptBool(trueValue2)
        #expect(b.value)
        b = ScriptBool(trueValue3)
        #expect(b.value)
    }
}
