import Foundation

extension ScriptContext {

    /// Removes the top stack item.
    mutating func opDrop() throws {
        _ = try getUnaryParam()
    }

    /// Removes the top two stack items.
    mutating func op2Drop() throws {
        _ = try getBinaryParams()
    }

    /// Duplicates the top stack item.
    mutating func opDup() throws {
        let first = try getUnaryParam()
        stack.append(first)
        stack.append(first)
    }

    /// If the top stack value is not 0, duplicate it.
    mutating func opIfDup() throws {
        guard let top = stack.last else {
            throw ScriptError.missingStackArgument
        }
        if top.isEmpty {
            return
        }
        try opDup()
    }

    /// Duplicates the top two stack items.
    mutating func op2Dup() throws {
        let (first, second) = try getBinaryParams()
        stack.append(first)
        stack.append(second)
        stack.append(first)
        stack.append(second)
    }

    /// Duplicates the top three stack items.
    mutating func op3Dup() throws {
        let (first, second, third) = try getTernaryParams()
        stack.append(first)
        stack.append(second)
        stack.append(third)
        stack.append(first)
        stack.append(second)
        stack.append(third)
    }

    /// The top two items on the stack are swapped.
    mutating func opSwap() throws {
        let (first, second) = try getBinaryParams()
        stack.append(second)
        stack.append(first)
    }

    /// Swaps the top two pairs of items.
    mutating func op2Swap() throws {
        let (x1, x2, x3, x4) = try getQuaternaryParams()
        stack.append(x3)
        stack.append(x4)
        stack.append(x1)
        stack.append(x2)
    }

    /// Copies the second-to-top stack item to the top.
    mutating func opOver() throws {
        let (first, second) = try getBinaryParams()
        stack.append(first)
        stack.append(second)
        stack.append(first)
    }

    /// Copies the pair of items two spaces back in the stack to the front.
    mutating func op2Over() throws {
        let (x1, x2, x3, x4) = try getQuaternaryParams()
        stack.append(x1)
        stack.append(x2)
        stack.append(x3)
        stack.append(x4)
        stack.append(x1)
        stack.append(x2)
    }

    /// The 3rd item down the stack is moved to the top.
    mutating func opRot() throws {
        let (first, second, third) = try getTernaryParams()
        stack.append(second)
        stack.append(third)
        stack.append(first)
    }

    /// The fifth and sixth items back are moved to the top of the stack.
    mutating func op2Rot() throws {
        let (x1, x2, x3, x4, x5, x6) = try getSenaryParams()
        stack.append(x3)
        stack.append(x4)
        stack.append(x5)
        stack.append(x6)
        stack.append(x1)
        stack.append(x2)
    }


    /// Removes the second-to-top stack item.
    mutating func opNip() throws {
        let (_, second) = try getBinaryParams()
        stack.append(second)
    }

    /// The item at the top of the stack is copied and inserted before the second-to-top item.
    mutating func opTuck() throws {
        let (first, second) = try getBinaryParams()
        stack.append(second)
        stack.append(first)
        stack.append(second)
    }

    /// The item n back in the stack is copied to the top.
    mutating func opPick() throws {
        let n = try getUnaryNumericParam().value
        guard n >= 0 && n < stack.count else {
            throw ScriptError.invalidStackOperation
        }
        let picked = stack[stack.endIndex - n - 1]
        stack.append(picked)
    }

    /// The item n back in the stack is moved to the top.
    mutating func opRoll() throws {
        let n = try getUnaryNumericParam().value
        guard n >= 0 && n < stack.count else {
            throw ScriptError.invalidStackOperation
        }
        let rolled = stack.remove(at: stack.endIndex - n - 1)
        stack.append(rolled)
    }

    /// Puts the number of stack items onto the stack.
    mutating func opDepth() throws {
        let count = try ScriptNumber(stack.count)
        stack.append(count.data)
    }

    /// Puts the input onto the top of the alt stack. Removes it from the main stack.
    mutating func opToAltStack() throws {
        let first = try getUnaryParam()
        altStack.append(first)
    }

    /// Puts the input onto the top of the main stack. Removes it from the alt stack.
    mutating func opFromAltStack() throws {
        guard altStack.count > 0 else {
            throw ScriptError.missingAltStackArgument
        }
        stack.append(altStack.removeLast())
    }
}
