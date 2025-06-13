import Collections

/// An index plus storage for headers.
actor TransientHeadersIndex: HeadersIndex {

    private var headers = OrderedDictionary<Block.ID, Block>()
    private var position = 0

    var isEmpty: Bool {
        headers.isEmpty
    }

    var first: Block? {
        guard !isEmpty else {
            return .none
        }
        return headers[headers.keys.first!]
    }

    var last: Block? {
        guard !isEmpty else {
            return .none
        }
        return headers[headers.keys.last!]
    }

    func add(_ header: Block) {
        headers[header.id] = header
    }

    func has(_ id: Block.ID) -> Bool {
        headers[id] != .none
    }

    func get(_ id: Block.ID) -> Block? {
        headers[id]
    }

    func removeFirst() {
        if headers.count > 0 {
            headers.removeFirst()
        }
    }
}
