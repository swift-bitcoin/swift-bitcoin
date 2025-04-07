import Testing
import Foundation
import BitcoinBase
import BitcoinCrypto
@testable import BitcoinMiniscript

struct Parser {

    @Test func ast() throws {
        let ast = try #require(try ASTNode("a:b:c:def(1)"))
        #expect(ast.description == "abc:def(1)")
    }

    @Test func mixedTimeHeight() throws {
        let exp = OrI(Older(1), Older(0x0040ffff))
        let miniscript = try Miniscript(exp.description)
        #expect(miniscript.evaluated == exp.compiled)
        #expect(!miniscript.properties.k)
    }

    @Test func mixedTimeHeightValid() throws {
        let exp = OrI(After(1), Older(0x0040ffff))
        let miniscript = try Miniscript(exp.description)
        #expect(miniscript.evaluated == exp.compiled)
        #expect(miniscript.properties.k)
    }
}
