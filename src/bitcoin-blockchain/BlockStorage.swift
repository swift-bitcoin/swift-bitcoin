/// Block storage service.
actor BlockStorage {

    typealias Locator = [TxBlock].Index

    private var blocks = [TxBlock]()

    func store(_ block: TxBlock) -> Locator {
        let locator = blocks.endIndex
        blocks.append(block)
        return locator
    }

    func store(_ block: TxBlock, at locator: Locator) {
        blocks[locator] = block
    }

    func retrieve(_ locator: Locator) -> TxBlock {
        blocks[locator]
    }

    func remove(_ locator: Locator) {
        blocks.remove(at: locator)
    }
}
