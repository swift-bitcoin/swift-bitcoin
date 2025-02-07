extension Database: Sequence {

    public typealias Iterator = Cursor

    public func makeIterator() -> Database.Iterator {
        return try! cursor()
    }

    public var underestimatedCount: Int {
        return count
    }
}
