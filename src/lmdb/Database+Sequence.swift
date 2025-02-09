extension Database: Sequence {
    // Currently this compliance is only used by `LMDBTests.cursor()`.

    public typealias Iterator = Cursor

    public func makeIterator() -> Database.Iterator {
        try! cursor()
    }

    public var underestimatedCount: Int { count }
}
