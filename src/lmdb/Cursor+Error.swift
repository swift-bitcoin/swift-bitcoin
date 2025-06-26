extension Cursor {

    package enum InitError: Error {
        case initialization, handler(Error)
    }
}
