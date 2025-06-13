import BitcoinBase

public extension Script {

    init(_ expression: MiniscriptExp) {
        self.init(expression.compiled)
    }

    init(_ expression: Miniscript) {
        self.init(expression.evaluated)
    }
}
