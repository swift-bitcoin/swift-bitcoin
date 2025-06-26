extension Environment {

    package enum InitError: Error {
        case createIssue, maxDatabasesIssue, maxReadersIssue, mapSizeIssue, openIssue
    }
}
