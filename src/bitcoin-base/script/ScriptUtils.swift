import Foundation
import BitcoinCrypto

func getUnaryNumericParam(_ stack: inout [Data], context: inout ScriptContext) throws -> ScriptNumber {
    let first = try getUnaryParam(&stack)
    let minimal = context.config.contains(.minimalData)
    let a = try ScriptNumber(first, minimal: minimal)
    return a
}

func getUnaryParam(_ stack: inout [Data], keep: Bool = false) throws -> Data {
    guard let param = stack.last else {
        throw ScriptError.missingStackArgument
    }
    if !keep { stack.removeLast() }
    return param
}

func getBinaryNumericParams(_ stack: inout [Data], context: inout ScriptContext) throws -> (ScriptNumber, ScriptNumber) {
    let (first, second) = try getBinaryParams(&stack)
    let minimal = context.config.contains(.minimalData)
    let a = try ScriptNumber(first, minimal: minimal)
    let b = try ScriptNumber(second, minimal: minimal)
    return (a, b)
}

func getBinaryParams(_ stack: inout [Data]) throws -> (Data, Data) {
    guard stack.count > 1 else {
        throw ScriptError.missingStackArgument
    }
    let second = stack.removeLast()
    let first = stack.removeLast()
    return (first, second)
}

func getTernaryNumericParams(_ stack: inout [Data], context: inout ScriptContext) throws -> (ScriptNumber, ScriptNumber, ScriptNumber) {
    let (first, second, third) = try getTernaryParams(&stack)
    let minimal = context.config.contains(.minimalData)
    let a = try ScriptNumber(first, minimal: minimal)
    let b = try ScriptNumber(second, minimal: minimal)
    let c = try ScriptNumber(third, minimal: minimal)
    return (a, b, c)
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

func getCheckMultiSigParams(_ stack: inout [Data], config: ScriptConfig) throws -> (Int, [Data], Int, [Data]) {
    guard stack.count > 4 else {
        throw ScriptError.missingMultiSigArgument
    }
    let n = try ScriptNumber(stack.removeLast(), minimal: config.contains(.minimalData)).value
    let publicKeys = Array(stack.suffix(n).reversed())
    stack.removeLast(n)
    let m = try ScriptNumber(stack.removeLast(), minimal: config.contains(.minimalData)).value
    let sigs = Array(stack.suffix(m).reversed())
    stack.removeLast(m)
    guard stack.count > 0 else {
        throw ScriptError.missingDummyValue
    }
    let dummyValue = stack.removeLast()
    if config.contains(.nullDummy), dummyValue.count > 0 {
        throw ScriptError.dummyValueNotNull
    }
    return (n, publicKeys, m, sigs)
}

// TODO: Move this logic into Signature struct somehow.
func checkSignature(_ extendedSignatureData: Data, scriptConfig: ScriptConfig) throws {
    // Empty signature. Not strictly DER encoded, but allowed to provide a
    // compact way to provide an invalid signature for use with CHECK(MULTI)SIG
    if extendedSignatureData.isEmpty { return }

    let signatureData = extendedSignatureData.dropLast()

    if scriptConfig.contains(.strictDER) || scriptConfig.contains(.lowS) || scriptConfig.contains(.strictEncoding) {
        guard let signature = Signature(signatureData, type: .ecdsa) else {
            fatalError()
        }
        guard signature.isEncodingValid else {
            throw ScriptError.invalidSignatureEncoding
        }
    }
    if scriptConfig.contains(.lowS) {
        guard let signature = Signature(signatureData, type: .ecdsa) else {
            fatalError()
        }
        guard signature.isLowS else {
            throw ScriptError.nonLowSSignature
        }
    }
    if scriptConfig.contains(.strictEncoding)  {

        // TODO: Initialize SighashType with byte value instead of Data but be careful to allow undefined values!
        guard let sighashTypeByte = extendedSignatureData.last, let sighashType = SighashType(Data([sighashTypeByte])) else {
            preconditionFailure()
        }
        guard sighashType.isDefined else {
            throw ScriptError.undefinedSighashType
        }
    }
}

func checkPublicKey(_ publicKeyData: Data, scriptVersion: SigVersion, scriptConfig: ScriptConfig) throws {
    if scriptConfig.contains(.strictEncoding) {
        // TODO: This may actually be checking that the uncompressed key is valid (as we convert it to compressed)
        guard let _ = PublicKey(publicKeyData) else {
            throw ScriptError.invalidPublicKeyEncoding
        }
    }
    // Only compressed keys are accepted in segwit
    if scriptVersion == .witnessV0 && scriptConfig.contains(.witnessCompressedPublicKey) {
        guard let _ = PublicKey(compressed: publicKeyData) else {
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
    if sigTmp.count == Signature.extendedSchnorrSignatureLength, let rawValue = sigTmp.popLast(), let maybeHashType = SighashType(rawValue) {
        // If the sig is 64 bytes long, return Verify(q, hashTapSighash(0x00 || SigMsg(0x00, 0)), sig), where Verify is defined in BIP340.
        sighashType = maybeHashType
    } else if sigTmp.count == Signature.schnorrSignatureLength {
        // If the sig is 65 bytes long, return sig[64] ≠ 0x00 and Verify(q, hashTapSighash(0x00 || SigMsg(sig[64], 0)), sig[0:64]).
        sighashType = SighashType?.none
    } else {
        // Otherwise, fail.
        throw ScriptError.invalidSchnorrSignatureFormat
    }
    let signature = sigTmp
    return (signature, sighashType)
}
