import ArgumentParser
import BitcoinBase

// TODO: Add `@retroactive` back once Swift on Linux is fixed.
extension SigVersion: /* @retroactive */ Decodable, /* @retroactive */ ExpressibleByArgument { }
