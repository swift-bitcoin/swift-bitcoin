import Foundation

/// The network type of a transaction block.
public enum BlockNetwork: UInt32, RawRepresentable, Equatable {
    case main = 0xd9b4bef9, test = 0x0709110b, regtest = 0xdab5bffa

    // main
    // (u32time   , u32nonce  , u32bits   , i32version, amountreward)
    // (1231006505, 2083236893, 0x1d00ffff, 1         , 50 * COIN)
    // magic number/message start: 0xd9b4bef9 (sent as little endian)
    // default port: 8333
    // hashGenesisBlock: 0x000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f
    // hashMerkleRoot: 0x4a5e1e4baab89f3a32518a88c31bc87f618f76673e2cc77ab2127b7afdeda33b
    //
    //
    // test
    // (u32time   , u32nonce  , u32bits   , i32version, amountreward)
    // (1296688602, 414098458 , 0x1d00ffff, 1         , 50 * COIN)
    // magic: 0x0709110b
    // default port: 18333
    // hashGenesisBlock: 0x000000000933ea01ad0ee984209779baaec3ced90fa3f408719526f8d77f4943
    // hashMerkleRoot: 0x4a5e1e4baab89f3a32518a88c31bc87f618f76673e2cc77ab2127b7afdeda33b
    //
    //
    // signet
    // (u32time   , u32nonce  , u32bits   , i32version, amountreward)
    // (1598918400, 52613770  , 0x1e0377ae, 1         , 50 * COIN)
    // magic: message start is defined as the first 4 bytes of the sha256d of the block script
    // default port: 38333
    // hashGenesisBlock: 0x00000008819873e925422c1ff0f99f7cc9bbb232af63a077a480a3633bee1ef6
    // hashMerkleRoot: 0x4a5e1e4baab89f3a32518a88c31bc87f618f76673e2cc77ab2127b7afdeda33b
    //
    //
    // regtest
    // (u32time   , u32nonce  , u32bits   , i32version, amountreward)
    // (1296688602, 2         , 0x207fffff, 1         , 50 * COIN);
    // magic: 0xdab5bffa
    // default port: 18444
    // hashGenesisBlock: 0x0f9188f13cb7b2c71f2a335e3a4fc328bf5beb436012afca590b1a11466e2206
    // hashMerkleRoot: 0x4a5e1e4baab89f3a32518a88c31bc87f618f76673e2cc77ab2127b7afdeda33b
    //
    // "difficulty": 4.656542373906925e-10,
    // "chainwork": "0000000000000000000000000000000000000000000000000000000000000002",
}
