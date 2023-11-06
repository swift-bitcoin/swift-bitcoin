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

func getCheckMultiSigParams(_ stack: inout [Data], configuration: ScriptConfigurarion) throws -> (Int, [Data], Int, [Data]) {
    guard stack.count > 4 else {
        throw ScriptError.invalidScript
    }
    let n = try ScriptNumber(stack.removeLast()).value
    let publicKeys = Array(stack[(stack.endIndex - n)...].reversed())
    stack.removeLast(n)
    let m = try ScriptNumber(stack.removeLast()).value
    let sigs = Array(stack[(stack.endIndex - m)...].reversed())
    stack.removeLast(m)
    let dummyValue = stack.removeLast()
    if configuration.nullDummy, dummyValue.count > 0 {
        throw ScriptError.dummyValueNotNull
    }
    return (n, publicKeys, m, sigs)
}

func checkSignature(_ extendedSignature: Data, scriptConfiguration: ScriptConfigurarion) throws {
    // Empty signature. Not strictly DER encoded, but allowed to provide a
    // compact way to provide an invalid signature for use with CHECK(MULTI)SIG
    if extendedSignature.isEmpty { return }
    if scriptConfiguration.strictDER || scriptConfiguration.lowS || scriptConfiguration.strictEncoding {
        try checkSignatureEncoding(extendedSignature)
    }
    if scriptConfiguration.lowS  {
        try checkSignatureLowS(extendedSignature)
    }
    if scriptConfiguration.strictEncoding  {
        let sighashTypeData = extendedSignature.dropFirst(extendedSignature.count - 1)
        guard let sighashType = SighashType(sighashTypeData), sighashType.isDefined else {
            throw ScriptError.undefinedSighashType
        }
    }
}

func checkPublicKey(_ publicKey: Data, scriptConfiguration: ScriptConfigurarion) throws {
    if scriptConfiguration.strictEncoding  {
        try checkPublicKeyEncoding(publicKey)
    }
}
