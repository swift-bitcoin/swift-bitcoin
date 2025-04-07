import BitcoinBase

/// "z" Zero-arg: this expression always consumes exactly 0 stack elements.
public protocol ModZ: MiniscriptExp { }

/// "o" One-arg: this expression always consumes exactly 1 stack element.
public protocol ModO: MiniscriptExp { }

/// "n" Nonzero: this expression always consumes at least 1 stack element, no satisfaction for this expression requires the top input stack element to be zero.
public protocol ModN: MiniscriptExp { }

/// "d" Dissatisfiable: a dissatisfaction for this expression can unconditionally be constructed. This implies the dissatisfaction cannot include any signature or hash preimage, and cannot rely on timelocks being satisfied.
public protocol ModD: MiniscriptExp { }
public protocol ModD_: MiniscriptExp { }

extension Never: @retroactive CustomStringConvertible {}
extension Never: ExpB, ExpW, ModD, ModD_ {
    public var compiled: [ScriptOp] { fatalError() }
    public var description: String { fatalError() }
}

/// "u" Unit: when satisfied, this expression will put an exact 1 on the stack (as opposed to any nonzero value).
public protocol ModU: MiniscriptExp { }
