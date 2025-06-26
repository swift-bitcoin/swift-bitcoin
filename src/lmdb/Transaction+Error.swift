import Foundation

extension Transaction {

    package enum InitError: Error {
        case beginIssue, databaseIssue, commitIssue, handlerIssue(Error)
    }

    package enum CommitError: Error {

        init(_ value: Int32) {
            self = switch value {
            case EACCES: .access
            case EINVAL: .invalid
            case EIO: .io
            default: .unknown(Int(value))
            }
        }

        /// `EACCES` - the environment is read-only.
        case access

        /// `EINVAL` - an invalid parameter was specified.
        case invalid

        /// `EIO` - an error occurred during synchronization.
        case io

        case unknown(Int)
    }
}
