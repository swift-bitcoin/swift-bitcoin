import Foundation

struct SighashCache {
    init(shaPrevouts: Data? = nil, shaPrevoutsUsed: Bool = false, shaAmounts: Data? = nil, shaAmountsUsed: Bool = false, shaScriptPubKeys: Data? = nil, shaScriptPubKeysUsed: Bool = false, shaSequences: Data? = nil, shaSequencesUsed: Bool = false, shaOuts: Data? = nil, shaOutsUsed: Bool = false) {
        self.shaPrevouts = shaPrevouts
        self.shaPrevoutsUsed = shaPrevoutsUsed
        self.shaAmounts = shaAmounts
        self.shaAmountsUsed = shaAmountsUsed
        self.shaScriptPubKeys = shaScriptPubKeys
        self.shaScriptPubKeysUsed = shaScriptPubKeysUsed
        self.shaSequences = shaSequences
        self.shaSequencesUsed = shaSequencesUsed
        self.shaOuts = shaOuts
        self.shaOutsUsed = shaOutsUsed
    }
    
    var shaPrevouts: Data?
    var shaPrevoutsUsed: Bool = false
    var shaAmounts: Data?
    var shaAmountsUsed: Bool = false
    var shaScriptPubKeys: Data?
    var shaScriptPubKeysUsed: Bool = false
    var shaSequences: Data?
    var shaSequencesUsed: Bool = false
    var shaOuts: Data?
    var shaOutsUsed: Bool = false
}
