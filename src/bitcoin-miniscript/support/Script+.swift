import BitcoinBase

extension Script {
    public init(_ expression: MiniscriptExp) {
        self.init(expression.compiled)
    }

    public init(_ expression: Miniscript) {
        self.init(expression.evaluated)
    }
}
