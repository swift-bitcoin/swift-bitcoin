import BitcoinBase

public extension BitcoinScript {

    init(_ expression: MiniscriptExp) {
        self.init(expression.compiled)
    }

    init(_ expression: Miniscript) {
        self.init(expression.evaluated)
    }
}
