import Foundation

func opCheckSig(_ stack: inout [Data], context: ScriptContext) throws {
    let (sig, publicKey) = try getBinaryParams(&stack)

    let result: Bool
    switch context.script.version {
        case .legacy:
        // Legacy semantics
        guard let scriptCode = context.getScriptCode(signature: sig) else {
            throw ScriptError.invalidScript
        }
        result = context.transaction.checkSignature(extendedSignature: sig, publicKey: publicKey, inputIndex: context.inputIndex, previousOutput: context.previousOutput, scriptCode: scriptCode)
        default:
            preconditionFailure()
    }
    stack.append(ScriptBoolean(result).data)
}
