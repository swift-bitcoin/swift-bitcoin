import CLMDB
import Foundation

extension Cursor {

    package enum Operation {

        /// Position at first key/data item
        case first

        /// Position at first data item of current key.
        /// Only for #MDB_DUPSORT
        case firstDup

        /// Position at key/data pair. Only for #MDB_DUPSORT
        case getBoth

        /// position at key, nearest data. Only for #MDB_DUPSORT
        case bothRange

        /// Return key/data at current cursor position
        case getCurrent

        /// Return up to a page of duplicate data items from current cursor position. Move cursor to prepare for #MDB_NEXT_MULTIPLE.
        /// Only for #MDB_DUPFIXED
        case getMultiple

        /// Position at last key/data item
        case last

        /// Position at last data item of current key. /// Only for #MDB_DUPSORT
        case lastDup

        /// Position at next data item
        case next

        /// Position at next data item of current key. /// Only for #MDB_DUPSORT
        case nextDup

        /// Return up to a page of duplicate data items from next cursor position. Move cursor to prepare for #MDB_NEXT_MULTIPLE.
        /// Only for #MDB_DUPFIXED
        case nextMultiple

        /// Position at first data item of next key
        case nextNodup

        /// Position at previous data item
        case prev

        /// Position at previous data item of current key.
        /// Only for #MDB_DUPSORT
        case prevDup

        /// Position at last data item of previous key
        case prevNodup

        /// Position at specified key
        case set

        /// Position at specified key, return key + data
        case setKey

        /// Position at first key greater than or equal to specified key.
        case setRange

        /// Position at previous page and return up to a page of duplicate data items.
        /// Only for #MDB_DUPFIXED
        case prevMultiple

        var value: MDB_cursor_op {
            switch self {
            case .first: MDB_FIRST
            case .firstDup: MDB_FIRST_DUP
            case .getBoth: MDB_GET_BOTH
            case .bothRange: MDB_GET_BOTH_RANGE
            case .getCurrent: MDB_GET_CURRENT
            case .getMultiple: MDB_GET_MULTIPLE
            case .last: MDB_LAST
            case .lastDup: MDB_LAST_DUP
            case .next: MDB_NEXT
            case .nextDup: MDB_NEXT_DUP
            case .nextMultiple: MDB_NEXT_MULTIPLE
            case .nextNodup: MDB_NEXT_NODUP
            case .prev: MDB_PREV
            case .prevDup: MDB_PREV_DUP
            case .prevNodup: MDB_PREV_NODUP
            case .set: MDB_SET
            case .setKey: MDB_SET_KEY
            case .setRange: MDB_SET_RANGE
            case .prevMultiple: MDB_PREV_MULTIPLE
            }
        }
    }
}
