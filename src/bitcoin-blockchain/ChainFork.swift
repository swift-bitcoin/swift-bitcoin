import Foundation

struct ChainFork: Equatable, Comparable {

    let tip: BlockRef
    var start: BlockRef

    init(_ tip: BlockRef) {
        self.tip = tip
        self.start = tip
    }

    static func < (lhs: ChainFork, rhs: ChainFork) -> Bool {
        lhs.tip.chainwork < rhs.tip.chainwork || (lhs.tip.chainwork == rhs.tip.chainwork && lhs.tip.status.score < rhs.tip.status.score)
    }
}

#if canImport(Playgrounds)

import Playgrounds

#Playground {
    let ref1 = BlockRef(.init(previous: .init(), merkleRoot: .init(), target: 0), height: 0, chainwork: .init(0), chainTxCount: 1, status: .merkle)
    let ref2 = BlockRef(.init(previous: .init(), merkleRoot: .init(), target: 0), height: 0, chainwork: .init(0), chainTxCount: 2, status: .stale)
    let ref3 = BlockRef(.init(previous: .init(), merkleRoot: .init(), target: 0), height: 0, chainwork: .init(0), chainTxCount: 3, status: .active)
    var tips = [ChainFork]([
        .init(ref1), .init(ref2), .init(ref3)
    ])
    tips.sort { $0 > $1 }
    // var counts = tips.map(\.tip.chainTxCount)
}

#endif
