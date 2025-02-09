import BitcoinCrypto

extension String: BinaryCodable {

    public init(from decoder: inout BinaryDecoder) throws(BinaryDecodingError) {
        let data = try decoder.decode()
        guard let maybeSelf = Self(data: data, encoding: .utf8) else {
            throw BinaryDecodingError.limitExceeded
        }
        self = maybeSelf
    }

    public func encode(to encoder: inout BinaryEncoder) {
        encoder.encode(data(using: .utf8)!)
    }

    public func encodingSize(_ counter: inout BinaryEncodingSizeCounter) {
        counter.countSize(data(using: .utf8)!.count)
    }
}
