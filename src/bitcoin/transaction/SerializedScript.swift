import Foundation

public struct SerializedScript: Equatable {

    public init(_ data: Data) {
        self.data = data
    }

    init?(prefixedData: Data) {
        guard let data = Data(varLenData: prefixedData) else {
            return nil
        }
        self.init(data)
    }

    private(set) var data: Data

    var prefixedData: Data {
        data.varLenData
    }

    var prefixedSize: Int {
        data.varLenSize
    }

    public static let empty = Self(.init())
}
