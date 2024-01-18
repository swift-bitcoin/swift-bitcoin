import Foundation
import BitcoinCrypto

func getUnaryParam(_ stack: inout [Data], keep: Bool = false) throws -> Data {
    guard let param = stack.last else {
        throw ScriptError.missingStackArgument
    }
    if !keep { stack.removeLast() }
    return param
}

func getBinaryParams(_ stack: inout [Data]) throws -> (Data, Data) {
    guard stack.count > 1 else {
        throw ScriptError.missingStackArgument
    }
    let second = stack.removeLast()
    let first = stack.removeLast()
    return (first, second)
}

func getTernaryParams(_ stack: inout [Data]) throws -> (Data, Data, Data) {
    guard stack.count > 2 else {
        throw ScriptError.missingStackArgument
    }
    let third = stack.removeLast()
    let (first, second) = try getBinaryParams(&stack)
    return (first, second, third)
}

func getQuaternaryParams(_ stack: inout [Data]) throws -> (Data, Data, Data, Data) {
    guard stack.count > 3 else {
        throw ScriptError.missingStackArgument
    }
    let fourth = stack.removeLast()
    let (first, second, third) = try getTernaryParams(&stack)
    return (first, second, third, fourth)
}

func getSenaryParams(_ stack: inout [Data]) throws -> (Data, Data, Data, Data, Data, Data) {
    guard stack.count > 5 else {
        throw ScriptError.missingStackArgument
    }
    let sixth = stack.removeLast()
    let fifth = stack.removeLast()
    let (first, second, third, fourth) = try getQuaternaryParams(&stack)
    return (first, second, third, fourth, fifth, sixth)
}

func getCheckMultiSigParams(_ stack: inout [Data], configuration: ScriptConfigurarion) throws -> (Int, [Data], Int, [Data]) {
    guard stack.count > 4 else {
        throw ScriptError.missingMultiSigArgument
    }
    let n = try ScriptNumber(stack.removeLast()).value
    let publicKeys = Array(stack[(stack.endIndex - n)...].reversed())
    stack.removeLast(n)
    let m = try ScriptNumber(stack.removeLast()).value
    let sigs = Array(stack[(stack.endIndex - m)...].reversed())
    stack.removeLast(m)
    guard stack.count > 0 else {
        throw ScriptError.missingDummyValue
    }
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
        guard checkSignatureEncoding(extendedSignature) else {
            throw ScriptError.invalidSignatureEncoding
        }
    }
    if scriptConfiguration.lowS && !isSignatureLowS(extendedSignature) {
        throw ScriptError.nonLowSSignature
    }
    if scriptConfiguration.strictEncoding  {
        let sighashTypeData = extendedSignature.dropFirst(extendedSignature.count - 1)
        guard let sighashType = SighashType(sighashTypeData) else {
            preconditionFailure()
        }
        guard sighashType.isDefined else {
            throw ScriptError.undefinedSighashType
        }
    }
}

func checkPublicKey(_ publicKey: Data, scriptVersion: SigVersion, scriptConfiguration: ScriptConfigurarion) throws {
    if scriptConfiguration.strictEncoding  {
        guard checkPublicKeyEncoding(publicKey) else {
            throw ScriptError.invalidPublicKeyEncoding
        }
    }
    // Only compressed keys are accepted in segwit
    if scriptVersion == .witnessV0 && scriptConfiguration.witnessCompressedPublicKey {
        guard checkCompressedPublicKeyEncoding(publicKey) else {
            throw ScriptError.invalidPublicKeyEncoding
        }
    }
}

func splitECDSASignature(_ extendedSignature: Data) -> (Data, SighashType) {
    precondition(!extendedSignature.isEmpty)
    let signature = extendedSignature.dropLast()
    let sighashTypeData = extendedSignature.dropFirst(extendedSignature.count - 1)
    guard let sighashType = SighashType(sighashTypeData) else {
        preconditionFailure()
    }
    return (signature, sighashType)
}

func splitSchnorrSignature(_ extendedSignature: Data) throws -> (Data, SighashType?) {
    var sigTmp = extendedSignature
    let sighashType: SighashType?
    if sigTmp.count == 65, let rawValue = sigTmp.popLast(), let maybeHashType = SighashType(rawValue) {
        // If the sig is 64 bytes long, return Verify(q, hashTapSighash(0x00 || SigMsg(0x00, 0)), sig), where Verify is defined in BIP340.
        sighashType = maybeHashType
    } else if sigTmp.count == 64 {
        // If the sig is 65 bytes long, return sig[64] ≠ 0x00 and Verify(q, hashTapSighash(0x00 || SigMsg(sig[64], 0)), sig[0:64]).
        sighashType = SighashType?.none
    } else {
        // Otherwise, fail.
        throw ScriptError.invalidSchnorrSignatureFormat
    }
    let signature = sigTmp
    return (signature, sighashType)
}
