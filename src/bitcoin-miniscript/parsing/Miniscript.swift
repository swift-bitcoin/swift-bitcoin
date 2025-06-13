import BitcoinBase

public struct Miniscript {

    public init(_ source: String) throws(ParseError) {
        guard let root = try ASTNode(source) else {
            throw .emptyExpression
        }
        self.root = root
        let desugared = root.desugared
        properties = try desugared.properties
        evaluated = try desugared.evaluated
    }

    let root: ASTNode?
    public let properties: MiniscriptProperties
    public let evaluated: [Script.Operation]
}
