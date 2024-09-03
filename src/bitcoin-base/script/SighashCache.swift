import Foundation

struct SighashCache {
    init(shaPrevouts: Data? = nil, shaAmounts: Data? = nil, shaScriptPubKeys: Data? = nil, shaSequences: Data? = nil, shaOuts: Data? = nil) {
        self.shaPrevouts = shaPrevouts
        self.shaAmounts = shaAmounts
        self.shaScriptPubKeys = shaScriptPubKeys
        self.shaSequences = shaSequences
        self.shaOuts = shaOuts
    }

    var shaPrevouts: Data?
    var shaAmounts: Data?
    var shaScriptPubKeys: Data?
    var shaSequences: Data?
    var shaOuts: Data?
    var shaPrevoutsHit: Bool = false
    var shaAmountsHit: Bool = false
    var shaScriptPubKeysHit: Bool = false
    var shaSequencesHit: Bool = false
    var shaOutsHit: Bool = false

    mutating func resetHits() {
        shaPrevoutsHit = false
        shaAmountsHit = false
        shaScriptPubKeysHit = false
        shaSequencesHit = false
        shaOutsHit = false
    }
}
