import ArgumentParser
import BitcoinWallet

// TODO: Add `@retroactive` back once Swift on Linux is fixed.
extension WalletNetwork: /* @retroactive */ Decodable, /* @retroactive */ ExpressibleByArgument { }
