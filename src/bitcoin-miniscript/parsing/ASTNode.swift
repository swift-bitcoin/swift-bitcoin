import BitcoinCrypto
import Foundation
import BitcoinBase

indirect enum ASTNode {
    case wrapper(String, ASTNode)
    case fragment(String, [ASTNode])
    case arg(String)

    init?(_ source: String) throws(ParseError) {
        var tokens = Token.tokenize(source)
        if tokens.isEmpty {
            return nil
        }
        self = try parseRecursive(&tokens)
        guard tokens.isEmpty else {
            throw .unrecognizedSymbolsAtEnd
        }
    }

    var desugared: Self {
        switch self {
        case let .wrapper(name, x):
            switch name {
            case "t":
                .fragment("and_v", [x.desugared, .arg("1")])
            case "l":
                .fragment("or_i", [.arg("0"), x.desugared])
            case "u":
                .fragment("or_i", [x.desugared, .arg("0")])
            default:
                .wrapper(name, x.desugared)
            }
        case let .fragment(name, args):
            switch name {
            case "pk":
                // TODO: Throw if args.isEmpty?
                .wrapper("c", .fragment("pk_k", [args[0].desugared]))
            case "pkh":
                // TODO: Throw if args.isEmpty?
                .wrapper("c", .fragment("pk_h", [args[0].desugared]))
            case "and_n":
                // TODO: Throw if args.count < 2
                .fragment("andor", [args[0].desugared, args[1].desugared, .arg("0")])
            default:
                .fragment(name, args.map(\.desugared))
            }
        case .arg(_):
            self
        }
    }

    var properties: MiniscriptProperties { get throws(ParseError) {
        let olderBlocks: Bool
        let olderSeconds: Bool
        let afterBlocks: Bool
        let afterSeconds: Bool
        switch self {
        case let .wrapper(_, x):
            let xProps = try x.properties
            olderBlocks = xProps.olderBlocks
            olderSeconds = xProps.olderSeconds
            afterBlocks = xProps.afterBlocks
            afterSeconds = xProps.afterSeconds
        case let .fragment(name, args):
            let props = try args.map { arg throws(ParseError) in try arg.properties }
            switch name {
            case "older":
                guard case let .arg(val) = args[0], let n = Int(val), n > Transaction.Input.Sequence.zeroLocktimeBlocks.sequenceValue, n <= Transaction.Input.Sequence.maxLocktimeSeconds.sequenceValue else {
                    throw .invalidArgumentValue
                }
                olderBlocks = n >= Transaction.Input.Sequence.zeroLocktimeBlocks.sequenceValue && n <= Transaction.Input.Sequence.maxLocktimeBlocks.sequenceValue
                olderSeconds = n >= Transaction.Input.Sequence.zeroLocktimeSeconds.sequenceValue && n <= Transaction.Input.Sequence.maxLocktimeSeconds.sequenceValue
                afterBlocks = false
                afterSeconds = false
            case "after":
                guard args.count == 1 else { fatalError("missing or too many args") }
                guard case let .arg(val) = args[0], let n = Int(val), n >= 0, n <= Transaction.Locktime.maxClock.locktimeValue else {
                    throw .invalidArgumentValue
                }
                afterBlocks = n >= Transaction.Locktime.minBlock.locktimeValue && n <= Transaction.Locktime.maxBlock.locktimeValue
                afterSeconds = n >= Transaction.Locktime.minClock.locktimeValue && n <= Transaction.Locktime.maxClock.locktimeValue
                olderBlocks = false
                olderSeconds = false
            default:
                olderBlocks = !props.allSatisfy { !$0.olderBlocks }
                olderSeconds = !props.allSatisfy { !$0.olderSeconds }
                afterBlocks = !props.allSatisfy { !$0.afterBlocks }
                afterSeconds = !props.allSatisfy { !$0.afterSeconds }
            }
        default:
            olderBlocks = false
            olderSeconds = false
            afterBlocks = false
            afterSeconds = false
        }

        let type: ExpressionType
        let mods: Set<TypeModifier>
        switch self {
        case let .wrapper(name, x):
            let xProps = try x.properties
            switch name {
            case "a":
                guard xProps.type == .B else {
                    throw .invalidWrapperArgumentType
                }
                var aux = Set<TypeModifier>()
                if xProps.mods.contains(.d) { aux.insert(.d) }
                if xProps.mods.contains(.u) { aux.insert(.u) }
                type = .W
                mods = aux
            case "s":
                guard xProps.type == .B, xProps.mods.contains(.o) else {
                    throw .invalidWrapperArgumentType
                }
                var aux = Set<TypeModifier>()
                if xProps.mods.contains(.d) { aux.insert(.d) }
                if xProps.mods.contains(.u) { aux.insert(.u) }
                type = .W
                mods = aux
            case "c":
                guard xProps.type == .K else {
                    throw .invalidWrapperArgumentType
                }
                var aux = Set<TypeModifier>()
                if xProps.mods.contains(.o) { aux.insert(.o) }
                if xProps.mods.contains(.n) { aux.insert(.n) }
                if xProps.mods.contains(.d) { aux.insert(.d) }
                aux.insert(.u)
                type = .B
                mods = aux
            case "d":
                guard xProps.type == .V, xProps.mods.contains(.z) else {
                    throw .invalidWrapperArgumentType
                }
                let aux = Set([TypeModifier.o, .n, .d])
                // TODO: Have `tapscript` as parameter
                //if tapscript { mods.append(.u) }
                type = .B
                mods = aux
            case "v":
                guard xProps.type == .B else {
                    throw .invalidWrapperArgumentType
                }
                var aux = Set<TypeModifier>()
                if xProps.mods.contains(.z) { aux.insert(.z) }
                if xProps.mods.contains(.o) { aux.insert(.o) }
                if xProps.mods.contains(.n) { aux.insert(.n) }
                type = .V
                mods = aux
            case "j":
                guard xProps.type == .B, xProps.mods.contains(.n) else {
                    throw .invalidWrapperArgumentType
                }
                var aux = Set([TypeModifier.n, .d])
                if xProps.mods.contains(.o) { aux.insert(.o) }
                if xProps.mods.contains(.u) { aux.insert(.u) }
                type = .B
                mods = aux
            case "n":
                guard xProps.type == .B else {
                    throw .invalidWrapperArgumentType
                }
                var aux = Set([TypeModifier.u])
                if xProps.mods.contains(.z) { aux.insert(.z) }
                if xProps.mods.contains(.o) { aux.insert(.o) }
                if xProps.mods.contains(.n) { aux.insert(.n) }
                if xProps.mods.contains(.d) { aux.insert(.d) }
                type = .B
                mods = aux
            default: throw .unrecognizedWrapper(name)
            }
        case let .fragment(name, args):
            switch name {
            case "pk_k":
                guard args.count == 1 else { throw .wrongArgumentCount(fragment: name) }
                type = .K
                mods = [.o, .n, .d, .u]
            case "pk_h":
                guard args.count == 1 else { throw .wrongArgumentCount(fragment: name) }
                type = .K
                mods = [.n, .d, .u]
            case "older", "after":
                guard args.count == 1 else { throw .wrongArgumentCount(fragment: name) }
                type = .B
                mods = [.z]
            case "sha256", "ripemd160", "hash256", "hash160":
                guard args.count == 1 else { throw .wrongArgumentCount(fragment: name) }
                type = .B
                mods = [.o, .n, .d, .u]
            case "andor":
                guard args.count == 3 else { throw .wrongArgumentCount(fragment: name) }
                let x = args[0]
                let y = args[1]
                let z = args[2]
                let xProps = try x.properties
                let yProps = try y.properties
                let zProps = try z.properties
                guard xProps.type == .B && xProps.mods.contains(.d) && xProps.mods.contains(.u) else {
                    throw .invalidFragmentArgumentType
                }
                type = switch (yProps.type, zProps.type) {
                case (.B, .B): .B
                case (.K, .K): .K
                case (.V, .V): .V
                default: throw .invalidFragmentArgumentType
                }
                var aux = Set<TypeModifier>()
                if xProps.mods.contains(.z) && yProps.mods.contains(.z) && zProps.mods.contains(.z) { aux.insert(.z) }
                if xProps.mods.contains(.z) && yProps.mods.contains(.o) && zProps.mods.contains(.o) || (xProps.mods.contains(.o) && yProps.mods.contains(.z) && zProps.mods.contains(.z)) { aux.insert(.o) }
                if yProps.mods.contains(.u) && zProps.mods.contains(.u) { aux.insert(.u) }
                if zProps.mods.contains(.d) { aux.insert(.d) }
                mods = aux
            case "and_v":
                guard args.count == 2 else { throw .wrongArgumentCount(fragment: name) }
                let x = args[0]
                let y = args[1]
                let xProps = try x.properties
                let yProps = try y.properties
                guard xProps.type == .V && (yProps.type == .B || yProps.type == .K || yProps.type == .V) else {
                    throw .invalidFragmentArgumentType
                }
                var aux = Set<TypeModifier>()
                if xProps.mods.contains(.z) && yProps.mods.contains(.z) { aux.insert(.z) }
                if xProps.mods.contains(.z) && yProps.mods.contains(.o) || (xProps.mods.contains(.o) && yProps.mods.contains(.z)) { aux.insert(.o) }
                if xProps.mods.contains(.n) || (xProps.mods.contains(.z) && yProps.mods.contains(.n)) { aux.insert(.n) }
                if yProps.mods.contains(.u) { aux.insert(.u) }
                type = yProps.type
                mods = aux
            case "and_b":
                guard args.count == 2 else { throw .wrongArgumentCount(fragment: name) }
                let x = args[0]
                let y = args[1]
                let xProps = try x.properties
                let yProps = try y.properties
                guard xProps.type == .B && yProps.type == .W else {
                    throw .invalidFragmentArgumentType
                }
                var aux = Set<TypeModifier>()
                if xProps.mods.contains(.z) && yProps.mods.contains(.z) { aux.insert(.z) }
                if xProps.mods.contains(.z) && yProps.mods.contains(.o) || (xProps.mods.contains(.o) && yProps.mods.contains(.z)) { aux.insert(.o) }
                if xProps.mods.contains(.n) || (xProps.mods.contains(.z) && yProps.mods.contains(.n)) { aux.insert(.n) }
                if xProps.mods.contains(.d) && yProps.mods.contains(.d) { aux.insert(.d) }
                type = .B
                mods = aux.union([.u])
            case "or_b":
                guard args.count == 2 else { throw .wrongArgumentCount(fragment: name) }
                let x = args[0]
                let z = args[1]
                let xProps = try x.properties
                let zProps = try z.properties
                guard xProps.type == .B, zProps.type == .W, xProps.mods.contains(.d), zProps.mods.contains(.d) else {
                    throw .invalidFragmentArgumentType
                }
                var aux = Set<TypeModifier>()
                if xProps.mods.contains(.z) && zProps.mods.contains(.z) { aux.insert(.z) }
                if xProps.mods.contains(.z) && zProps.mods.contains(.o) || (xProps.mods.contains(.o) && zProps.mods.contains(.z)) { aux.insert(.o) }
                type = .B
                mods = aux.union([.d, .u])
            case "or_c":
                guard args.count == 2 else { throw .wrongArgumentCount(fragment: name) }
                let x = args[0]
                let z = args[1]
                let xProps = try x.properties
                let zProps = try z.properties
                guard xProps.type == .B, zProps.type == .V, xProps.mods.contains(.d), xProps.mods.contains(.u) else {
                    throw .invalidFragmentArgumentType
                }
                var aux = Set<TypeModifier>()
                if xProps.mods.contains(.z) && zProps.mods.contains(.z) { aux.insert(.z) }
                if xProps.mods.contains(.o) && zProps.mods.contains(.z) { aux.insert(.o) }
                type = .V
                mods = aux
            case "or_d":
                guard args.count == 2 else { throw .wrongArgumentCount(fragment: name) }
                let x = args[0]
                let z = args[1]
                let xProps = try x.properties
                let zProps = try z.properties
                guard xProps.type == .B, zProps.type == .B, xProps.mods.contains(.d), xProps.mods.contains(.u) else {
                    throw .invalidFragmentArgumentType
                }
                var aux = Set<TypeModifier>()
                if xProps.mods.contains(.z) && zProps.mods.contains(.z) { aux.insert(.z) }
                if xProps.mods.contains(.o) && zProps.mods.contains(.z) { aux.insert(.o) }
                if zProps.mods.contains(.d) { aux.insert(.d) }
                if zProps.mods.contains(.u) { aux.insert(.u) }
                type = .B
                mods = aux
            case "or_i":
                guard args.count == 2 else { throw .wrongArgumentCount(fragment: name) }
                let x = args[0]
                let z = args[1]
                let xProps = try x.properties
                let zProps = try z.properties
                guard xProps.type == .B || xProps.type == .K || xProps.type == .V && zProps.type == xProps.type else {
                    throw .invalidFragmentArgumentType
                }
                var aux = Set<TypeModifier>()
                if xProps.mods.contains(.z) && zProps.mods.contains(.z) { aux.insert(.o) }
                if xProps.mods.contains(.u) && zProps.mods.contains(.u) { aux.insert(.u) }
                if xProps.mods.contains(.d) || zProps.mods.contains(.d) { aux.insert(.d) }
                type = xProps.type
                mods = aux
            case "thresh":
                guard args.count >= 2, case let .arg(val) = args[0], let k = UInt8(val), k <= args.count - 1 else {
                    throw .invalidArgumentValue
                }
                let props = try args.dropFirst().map { arg throws(ParseError) in try arg.properties }
                guard props[0].type == .B && props[0].mods.contains(.d) && props[0].mods.contains(.u) else {
                    throw .invalidFragmentArgumentType
                }
                for prop in props.dropFirst() {
                    guard prop.type == .W && prop.mods.contains(.d) && prop.mods.contains(.u) else {
                        throw .invalidFragmentArgumentType
                    }
                }
                var aux = Set<TypeModifier>()
                if props.allSatisfy({ $0.mods.contains(.z) }) {
                    aux.insert(.z)
                }
                var zCount = 0
                var oNonZCount = 0
                for prop in props {
                    if prop.mods.contains(.z) {
                        zCount += 1
                    }
                    if !prop.mods.contains(.z) && prop.mods.contains(.o) {
                        oNonZCount += 1
                    }
                }
                if zCount == props.count - 1 && oNonZCount == 1 {
                    aux.insert(.o)
                }
                type = .B
                mods = aux.union([.d, .u])
            case "multi":
                type = .B
                mods = [.n, .d, .u]
            case "multi_a":
                type = .B
                mods = [.d, .u]
            default: throw .unrecognizedFragment(name)
            }
        case let .arg(value):
            switch value {
            case "0":
                type = .B
                mods = [.z, .u, .d]
            case "1":
                type = .B
                mods = [.z, .u]
            default:
                type = .constant
                mods = []
            }
        }
        return .init(type, mods, olderBlocks: olderBlocks, olderSeconds: olderSeconds, afterBlocks: afterBlocks, afterSeconds: afterSeconds)
    } }

    var evaluated: [Script.Operation] { get throws(ParseError) {
        switch self {
        case let .wrapper(name, x):
            var x = try x.evaluated
            switch name {
            case "a": return [.toAltStack] + x + [.fromAltStack]
            case "s": return [.swap] + x
            case "c": return x + [.checkSig]
            case "d": return [.dup, .if] + x + [.endIf]
            case "v":
                guard let lastOp = x.popLast() else {
                    throw .invalidWrapperArgument
                }
                return switch lastOp {
                case .checkSig: x + [.checkSigVerify]
                case .checkMultisig: x + [.checkMultisigVerify]
                case .equal: x + [.equalVerify]
                case .numEqual: x + [.numEqualVerify]
                default: x + [lastOp, .verify]
                }
            case "j": return [.size, .zeroNotEqual, .if] + x + [.endIf]
            case "n": return x + [.zeroNotEqual]
            default: throw .unrecognizedWrapper(name)
            }
        case let .fragment(name, args):
            switch name {
            case "pk_k":
                guard case let .arg(val) = args[0], let data = Data(hex: val), let key = PublicKey(compressed: data) else {
                    throw .invalidArgumentValue
                }
                return [.pushBytes(key.compressedData!)]
            case "pk_h":
                guard case let .arg(val) = args[0], let data = Data(hex: val), let key = PublicKey(compressed: data) else {
                    fatalError("invalid arg")
                }
                let hash = Data(BitcoinCrypto.Hash160.hash(data: key.compressedData!)) // TODO: For tapscript should be key.xOnlyData
                return [.dup, .hash160,  .pushBytes(hash), .equalVerify]
            case "older":
                guard case let .arg(val) = args[0], let n = Int(val) else {
                    throw .invalidArgumentValue
                }
                return [.encodeMinimally(n), .checkSequenceVerify]
            case "after":
                guard args.count == 1 else { fatalError("missing or too many args") }
                guard case let .arg(val) = args[0], let n = Int(val) else {
                    throw .invalidArgumentValue
                }
                return [.encodeMinimally(n), .checkLocktimeVerify]
            case "sha256":
                guard case let .arg(v) = args[0], let h = Data(hex: v), h.count == BitcoinCrypto.SHA256.Digest.byteCount else {
                    throw .invalidArgumentValue
                }
                return [.size, .encodeMinimally(0x20), .equalVerify, .sha256, .pushBytes(h), .equal]
            case "ripemd160":
                guard case let .arg(v) = args[0], let h = Data(hex: v), h.count == BitcoinCrypto.RIPEMD160.Digest.byteCount else {
                    throw .invalidArgumentValue
                }
                return [.size, .encodeMinimally(0x20), .equalVerify, .ripemd160, .pushBytes(h), .equal]
            case "hash256":
                guard case let .arg(v) = args[0], let h = Data(hex: v), h.count == BitcoinCrypto.Hash256.Digest.byteCount else {
                    throw .invalidArgumentValue
                }
                return [.size, .encodeMinimally(0x20), .equalVerify, .hash256, .pushBytes(h), .equal]
            case "hash160":
                guard case let .arg(v) = args[0], let h = Data(hex: v), h.count == BitcoinCrypto.Hash160.Digest.byteCount else {
                    throw .invalidArgumentValue
                }
                return [.size, .encodeMinimally(0x20), .equalVerify, .hash160, .pushBytes(h), .equal]
            case "andor":
                let x = args[0]
                let y = args[1]
                let z = args[2]
                return (try x.evaluated) + [.notIf] + (try z.evaluated) + [.else] + (try y.evaluated) + [.endIf]
            case "and_v":
                let x = args[0]
                let y = args[1]
                return (try x.evaluated) + (try y.evaluated)
            case "and_b":
                let x = args[0]
                let y = args[1]
                return (try x.evaluated) + (try y.evaluated) + [.boolAnd]
            case "or_b":
                let x = args[0]
                let z = args[1]
                return (try x.evaluated) + (try z.evaluated) + [.boolOr]
            case "or_c":
                let x = args[0]
                let z = args[1]
                return (try x.evaluated) + [.notIf] + (try z.evaluated) + [.endIf]
            case "or_d":
                let x = args[0]
                let z = args[1]
                return (try x.evaluated) + [.ifDup, .notIf] + (try z.evaluated) + [.endIf]
            case "or_i":
                let x = args[0]
                let z = args[1]
                return [.if] + (try x.evaluated) + [.else] + (try z.evaluated) + [.endIf]
            case "thresh":
                guard case let .arg(val) = args[0], let k = UInt8(val), k <= args.count - 1, k <= args.count - 1 else {
                    throw .invalidArgumentValue
                }
                let x0 = args[1]
                var extraOps = [Script.Operation]()
                for xi in args.dropFirst(2) {
                    extraOps += (try xi.evaluated) + [.add]
                }
                return (try x0.evaluated) + extraOps + [.constant(k), .equal]
            case "multi":
                guard case let .arg(val) = args[0], let k = UInt8(val) else {
                    throw .invalidArgumentValue
                }
                let n = UInt8(args.count - 1)
                let keysPushBytes = try args.dropFirst().map { arg throws(ParseError) in
                    guard  case let .arg(val) = arg, let data = Data(hex: val), let key = PublicKey(compressed: data), let keyData = key.compressedData else { throw .invalidArgumentValue }
                    return keyData
                }.map { Script.Operation.pushBytes($0) }
                return [.constant(k)] + keysPushBytes + [.constant(n), .checkMultisig]
            case "multi_a":
                guard case let .arg(val) = args[0], let k = UInt8(val) else {
                    throw .invalidArgumentValue
                }
                let keys = try args.dropFirst().map { arg throws(ParseError) in
                    guard  case let .arg(val) = arg, let data = Data(hex: val), let key = PublicKey(xOnly: data) else { throw .invalidArgumentValue }
                    return key
                }
                let keysPushBytes = keys.dropFirst().map(\.xOnlyData).flatMap {
                    [Script.Operation.pushBytes($0), .checkSigAdd]
                }
                return [.pushBytes(keys[0].xOnlyData), .checkSig] + keysPushBytes + [.checkSigAdd, .constant(k), .numEqual]
            default: throw .unrecognizedFragment(name)
            }
        case let .arg(value):
            guard let n = Int(value), n == 0 || n == 1 else {
                preconditionFailure("Non-base expression")
            }
            return [.encodeMinimally(n)]
        }
    } }
}

extension ASTNode: CustomStringConvertible {
    var description: String {
        switch self {
        case let .wrapper(name, arg):
            if case .wrapper(_, _) = arg {
                "\(name)\(arg.description)"
            } else {
                "\(name):\(arg.description)"
            }
        case let .fragment(name, args):
            "\(name)(\(args.map(\.description).joined(separator: ",")))"
        case let .arg(value):
            value.description
        }
    }
}

private func parseRecursive(_ tokens: inout [Token]) throws(ParseError) -> ASTNode {
    let token = tokens.removeFirst()
    switch token {
    case let .argument(value):
        return .arg(value)
    case let .wrapper(name):
        guard var next = tokens.first else {
            throw .missingWrapperArgument
        }
        if case .colon = next {
            tokens.removeFirst()
            guard let nextNext = tokens.first else {
                throw .missingWrapperArgument
            }
            next = nextNext
        }
        switch next {
        case .wrapper(_), .fragment(_): break
        default: throw .invalidWrapperArgument
        }
        return .wrapper(name, try parseRecursive(&tokens))
    case let .fragment(name):
        guard let next = tokens.first, case .parenOpen = next else {
            throw .missingFragmentArguments
        }
        tokens.removeFirst()
        guard let nextNext = tokens.first else {
            throw .missingFragmentArguments
        }
        switch nextNext {
        case .argument(_), .wrapper(_), .fragment(_): break
        default: throw .invalidFragmentArgument
        }
        var more = true
        var args = [ASTNode]()
        while more {
            args.append(try parseRecursive(&tokens))
            guard let next = tokens.first else {
                throw .invalidFragmentArguments
            }
            switch next {
            case .parenClose:
                tokens.removeFirst()
                more = false
            case .comma:
                tokens.removeFirst()
                // If we got a comma, next must be a legit arg
                guard let nextNext = tokens.first else {
                    throw .missingFragmentArguments
                }
                switch nextNext {
                case .argument(_), .wrapper(_), .fragment(_): break
                default: throw .invalidFragmentArgument
                }
            default:
                // Not ",", not ")"
                throw .invalidFragmentArguments
            }
        }
        return .fragment(name, args)
    default:
        throw .unrecognizedSymbol
    }
}
