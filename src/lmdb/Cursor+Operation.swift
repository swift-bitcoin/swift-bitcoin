import CLMDB
import Foundation

extension Cursor {

    package enum Operation {

        case first, last, next, previous, current

        var value: MDB_cursor_op {
            switch self {
            case .first: MDB_FIRST
            case .last: MDB_LAST
            case .next: MDB_NEXT
            case .previous: MDB_PREV
            case .current: MDB_GET_CURRENT
            }
        }
    }
}
