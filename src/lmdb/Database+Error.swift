extension Database {

    package enum AccessError: Error {
        case putIssue, getIssue, deleteIssue, dropIssue, statisticsIssue
    }
}
