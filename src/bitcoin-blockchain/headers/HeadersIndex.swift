/// An index plus storage for headers.
protocol HeadersIndex: Sendable {
    var isEmpty: Bool { get async }
    var first: TxBlock? { get async }
    var last: TxBlock? { get async }
    func add(_ header: TxBlock) async
    func has(_ id: BlockID) async -> Bool
    func get(_ id: BlockID) async -> TxBlock? // TODO: Probably should throw
    func removeFirst() async
}
