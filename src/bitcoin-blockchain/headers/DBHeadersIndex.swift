import Collections

/// An index plus storage for headers.
actor InMemoryHeadersIndex: HeadersIndex {

    private var headers = OrderedDictionary<BlockID, TxBlock>()
    private var position = 0

    var isEmpty: Bool {
        headers.isEmpty
    }

    var first: TxBlock? {
        guard !isEmpty else {
            return .none
        }
        return headers[headers.keys.first!]
    }

    var last: TxBlock? {
        guard !isEmpty else {
            return .none
        }
        return headers[headers.keys.last!]
    }

    func add(_ header: TxBlock) {
        headers[header.id] = header
    }

    func has(_ id: BlockID) -> Bool {
        headers[id] != .none
    }

    func get(_ id: BlockID) -> TxBlock? {
        headers[id]
    }

    func removeFirst() {
        if headers.count > 0 {
            headers.removeFirst()
        }
    }
}
