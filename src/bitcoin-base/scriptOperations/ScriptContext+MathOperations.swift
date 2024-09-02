import Foundation

extension ScriptContext {

    /// The number -1 is pushed onto the stack.
    mutating func op1Negate() {
        stack.append(ScriptNumber.negativeOne.data)
    }

    /// The input is made positive.
    mutating func opAbs() throws {
        var a = try getUnaryNumericParam()
        if a.value < 0 {
            a.negate()
        }
        stack.append(a.data)
    }

    /// The sign of the input is flipped.
    mutating func opNegate() throws {
        var a = try getUnaryNumericParam()
        a.negate()
        stack.append(a.data)
    }

    /// 1 is added to the input.
    mutating func op1Add() throws {
        var a = try getUnaryNumericParam()
        try a.add(.one)
        stack.append(a.data)
    }

    /// b is subtracted from a.
    mutating func op1Sub() throws {
        var a = try getUnaryNumericParam()
        try a.add(.negativeOne)
        stack.append(a.data)
    }

    /// a is added to b.
    mutating func opAdd() throws {
        var a: ScriptNumber
        let b: ScriptNumber
        (a, b) = try getBinaryNumericParams()
        try a.add(b)
        stack.append(a.data)
    }

    /// b is subtracted from a.
    mutating func opSub() throws {
        var (a, b) = try getBinaryNumericParams()
        b.negate()
        try a.add(b)
        stack.append(a.data)
    }

    /// If both a and b are not 0, the output is 1. Otherwise 0.
    mutating func opBoolAnd() throws {
        let (a, b) = try getBinaryNumericParams()
        stack.append(ScriptBoolean(a != .zero && b != .zero).data)
    }
    
    /// If a or b is not 0, the output is 1. Otherwise 0.
    mutating func opBoolOr() throws {
        let (a, b) = try getBinaryNumericParams()
        stack.append(ScriptBoolean(a != .zero || b != .zero).data)
    }

    /// If the input is 0 or 1, it is flipped. Otherwise the output will be 0.
    mutating func opNot() throws {
        let a = try getUnaryNumericParam()
        stack.append(ScriptBoolean(a == .zero).data)
    }

    /// Returns 0 if the input is 0. 1 otherwise.
    mutating func op0NotEqual() throws {
        let a = try getUnaryNumericParam()
        stack.append(ScriptBoolean(a != .zero).data)
    }

    /// Returns 1 if the numbers are equal, 0 otherwise.
    mutating func opNumEqual() throws {
        let (a, b) = try getBinaryNumericParams()
        stack.append(ScriptBoolean(a == b).data)
    }
    
    /// Same as `OP_NUMEQUAL`,  but runs `OP_VERIFY` afterward.
    mutating func opNumEqualVerify() throws {
        try opNumEqual()
        try opVerify()
    }
    
    /// Returns 1 if the numbers are not equal, 0 otherwise.
    mutating func opNumNotEqual() throws {
        let (a, b) = try getBinaryNumericParams()
        stack.append(ScriptBoolean(a != b).data)
    }

    /// Returns 1 if a is greater than b, 0 otherwise.
    mutating func opGreaterThan() throws {
        let (a, b) = try getBinaryNumericParams()
        stack.append(ScriptBoolean(a.value > b.value).data)
    }
    
    /// Returns 1 if a is greater than or equal to b, 0 otherwise.
    mutating func opGreaterThanOrEqual() throws {
        let (a, b) = try getBinaryNumericParams()
        stack.append(ScriptBoolean(a.value >= b.value).data)
    }

    /// Returns 1 if a is less than b, 0 otherwise.
    mutating func opLessThan() throws {
        let (a, b) = try getBinaryNumericParams()
        stack.append(ScriptBoolean(a.value < b.value).data)
    }
    
    /// Returns 1 if a is less than or equal to b, 0 otherwise.
    mutating func opLessThanOrEqual() throws {
        let (a, b) = try getBinaryNumericParams()
        stack.append(ScriptBoolean(a.value <= b.value).data)
    }

    /// Returns 1 if x is within the specified range (left-inclusive), 0 otherwise.
    mutating func opWithin() throws {
        let (a, min, max) = try getTernaryNumericParams()
        stack.append(ScriptBoolean(min.value <= a.value && a.value < max.value).data)
    }

    /// Returns the smaller of a and b.
    mutating func opMin() throws {
        let (a, b) = try getBinaryNumericParams()
        stack.append((a.value < b.value ? a : b).data)
    }
    
    /// Returns the larger of a and b.
    mutating func opMax() throws {
        let (a, b) = try getBinaryNumericParams()
        stack.append((a.value > b.value ? a : b).data)
    }
}
