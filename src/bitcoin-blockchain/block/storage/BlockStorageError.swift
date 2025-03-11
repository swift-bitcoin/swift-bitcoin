enum BlockStorageError: Error {
    case dataLocationIssue, missingBlockFiles, blockFileReadIssue, blockFileWriteIssue, blockFileCreateIssue, corruptedBlockData, invalidFileRef
}
