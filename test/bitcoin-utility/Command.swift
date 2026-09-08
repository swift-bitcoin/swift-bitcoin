import Testing
import ArgumentParser
@testable import BitcoinUtility

@Test func defaultCommand() throws {
    var maybeCommand = ParsableCommand?.none
    #expect(throws: Never.self) {
        maybeCommand = try BitcoinUtility.parseAsRoot([""])
    }
    try #require(maybeCommand != nil)
    guard let command = maybeCommand else {
        Issue.record()
        return
    }
    guard var defaultCommand = command as? SendCommand else {
        Issue.record()
        return
    }
    #expect(throws: Never.self) {
        try defaultCommand.validate()
    }
}
