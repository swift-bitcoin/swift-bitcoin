import Foundation

// - MARK: Hexadecimal encoding/decoding

extension Data {

    /// Create instance from string containing hex digits.
    init?(hex: String) {
        guard let regex = try? NSRegularExpression(pattern: "([0-9a-fA-F]{2})", options: []) else {
            return nil
        }
        let range = NSRange(location: 0, length: hex.count)
        let bytes = regex.matches(in: hex, options: [], range: range)
            .compactMap { Range($0.range(at: 1), in: hex) }
            .compactMap { UInt8(hex[$0], radix: 16) }
        self.init(bytes)
    }
}
