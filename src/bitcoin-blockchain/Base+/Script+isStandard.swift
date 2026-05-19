import Foundation
import BitcoinBase

/// Script standardness.
extension Script {
    // bool IsStandard(const CScript& scriptPubKey, TxoutType& whichType)
    func isStandard() -> OutputType? {

        let (whichType, solutions) = solveOutputType()

        if whichType == .nonStandard {
            return nil
        } else if whichType == .multisig {
            let m = solutions.first![0]
            let n = solutions.last![0]
            // Support up to x-of-3 multisig txns as standard
            if n < 1 || n > 3 {
                return nil
            }
            if m < 1 || m > n {
                return nil
            }
        }
        return whichType
    }
}
