public struct MiniscriptProperties {

    init(_ type: ExpressionType, _ mods: Set<TypeModifier>, olderBlocks: Bool = false, olderSeconds: Bool = false, afterBlocks: Bool = false, afterSeconds: Bool = false) {
        self.type = type
        self.mods = mods
        self.olderBlocks = olderBlocks
        self.olderSeconds = olderSeconds
        self.afterBlocks = afterBlocks
        self.afterSeconds = afterSeconds
    }

    public let type: ExpressionType
    public let mods: Set<TypeModifier>

    let olderBlocks: Bool
    let olderSeconds: Bool
    let afterBlocks: Bool
    let afterSeconds: Bool

    /// "k" No timelock mixing. This expression does not contain a mix of heightlock and timelock of the same type. If the miniscript does not have the "k" property, the miniscript template will not match the user expectation of the corresponding spending policy.
    public var k: Bool { !(olderBlocks && olderSeconds) && !(afterBlocks && afterSeconds)}
}
