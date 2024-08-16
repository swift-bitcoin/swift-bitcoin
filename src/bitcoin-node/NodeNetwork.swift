import ArgumentParser
import BitcoinBlockchain

// TODO: Add `@retroactive` back once Swift on Linux is fixed.
extension NodeNetwork: /* @retroactive */ Decodable, /* @retroactive */ ExpressibleByArgument { }
