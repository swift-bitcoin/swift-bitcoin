import Foundation
import ECCHelper

public func eccStart() {
    cECCStart(getRandBytesExtern(_:_:))
}

public func eccStop() {
    cECCStop()
}
