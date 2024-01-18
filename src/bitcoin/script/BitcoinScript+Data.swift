import Foundation

extension BitcoinScript {

    /// Creates a script from raw data.
    ///
    /// The script will be fully parsed – if possble. Any unparsable data will be stored separately.
    public init(_ data: Data, sigVersion: SigVersion = .base) {
        var data = data
        var operations = [ScriptOperation]()
        while data.count > 0 {
            guard let operation = ScriptOperation(data, sigVersion: sigVersion) else {
                break
            }
            operations.append(operation)
            data = data.dropFirst(operation.size)
        }
        self.sigVersion = sigVersion
        self.operations = operations
        self.unparsable = data
    }

    init?(prefixedData: Data, sigVersion: SigVersion = .base) {
        guard let data = Data(varLenData: prefixedData) else {
            return nil
        }
        self.init(data)
    }

    // MARK: - Computed Properties

    /// Serialization of the script's operations into raw data. May include unparsable data.
    var data: Data {
        operations.reduce(Data()) { $0 + $1.data } + unparsable
    }

    var size: Int {
        operations.reduce(0) { $0 + $1.size } + unparsable.count
    }

    var prefixedData: Data {
        data.varLenData
    }

    var prefixedSize: Int {
        UInt64(size).varIntSize + size
    }
}
