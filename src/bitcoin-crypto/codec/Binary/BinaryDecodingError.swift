import Foundation

/// An error that occurs during the decoding of a binary value.
public enum BinaryDecodingError: Error {

    /// Attempt to consume more data than it is available.
    case outOfRange

    /// The explicitly set limit was exceeded.
    case limitExceeded
}
