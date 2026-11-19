public import struct BitcoinBase.Script

extension Script {
    public init(_ expression: any MiniscriptExp) {
        self.init(expression.compiled)
    }

    public init(_ expression: Miniscript) {
        self.init(expression.evaluated)
    }
}
