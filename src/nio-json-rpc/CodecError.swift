enum CodecError: Error {
    case badFraming
    case badJSON(Error)
    case requestTooLarge
}
