import Foundation

func getUnaryParam(_ stack: inout [Data], keep: Bool = false) throws -> Data {
    guard let param = stack.last else {
        throw ScriptError.invalidScript
    }
    if !keep { stack.removeLast() }
    return param
}

func getBinaryParams(_ stack: inout [Data]) throws -> (Data, Data) {
    guard stack.count > 1 else {
        throw ScriptError.invalidScript
    }
    let second = stack.removeLast()
    let first = stack.removeLast()
    return (first, second)
}

func getTernaryParams(_ stack: inout [Data]) throws -> (Data, Data, Data) {
    guard stack.count > 2 else {
        throw ScriptError.invalidScript
    }
    let third = stack.removeLast()
    let (first, second) = try getBinaryParams(&stack)
    return (first, second, third)
}

func getQuaternaryParams(_ stack: inout [Data]) throws -> (Data, Data, Data, Data) {
    guard stack.count > 3 else {
        throw ScriptError.invalidScript
    }
    let fourth = stack.removeLast()
    let (first, second, third) = try getTernaryParams(&stack)
    return (first, second, third, fourth)
}

func getSenaryParams(_ stack: inout [Data]) throws -> (Data, Data, Data, Data, Data, Data) {
    guard stack.count > 5 else {
        throw ScriptError.invalidScript
    }
    let sixth = stack.removeLast()
    let fifth = stack.removeLast()
    let (first, second, third, fourth) = try getQuaternaryParams(&stack)
    return (first, second, third, fourth, fifth, sixth)
}

func getCheckMultiSigParams(_ stack: inout [Data]) throws -> (Int, [Data], Int, [Data]) {
    guard stack.count > 4 else {
        throw ScriptError.invalidScript
    }
    let n = try ScriptNumber(stack.removeLast()).value
    let publicKeys = Array(stack[(stack.endIndex - n)...].reversed())
    stack.removeLast(n)
    let m = try ScriptNumber(stack.removeLast()).value
    let sigs = Array(stack[(stack.endIndex - m)...].reversed())
    stack.removeLast(m)
    let nullDummy = stack.removeLast()
    guard nullDummy.count == 0 else {
        throw ScriptError.invalidScript
    }
    return (n, publicKeys, m, sigs)
}
