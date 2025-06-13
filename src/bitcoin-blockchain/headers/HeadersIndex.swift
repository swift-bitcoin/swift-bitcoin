/// An index plus storage for headers.
protocol HeadersIndex: Sendable {
    var isEmpty: Bool { get async }
    var first: Block? { get async }
    var last: Block? { get async }
    func add(_ header: Block) async
    func has(_ id: Block.ID) async -> Bool
    func get(_ id: Block.ID) async -> Block? // TODO: Probably should throw
    func removeFirst() async
}
