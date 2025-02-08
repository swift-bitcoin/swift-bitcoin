extension Database: Sequence {

    public typealias Iterator = Cursor

    public func makeIterator() -> Database.Iterator {
        try! cursor()
    }

    public var underestimatedCount: Int { count }
}
