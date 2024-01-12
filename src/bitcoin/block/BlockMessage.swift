import Foundation

/// A message containing a block.
public struct BlockMessage: Equatable {

    // MARK: - Initializers

    public init(block: TransactionBlock, network: BlockNetwork = .main) {
        self.block = block
        self.network = network
    }

    /// Initialize from serialized raw data.
    public init?(_ data: Data) {
        // Check we at least have enough data for magic number + block size + block
        guard data.count >= 88 else {
            return nil
        }
        var data = data

        // Magic number (aka message start)
        let magicNumber = data.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
        data = data.dropFirst(MemoryLayout.size(ofValue: magicNumber))
        guard let network = BlockNetwork(rawValue: magicNumber) else { return nil }
        self.network = network

        // Remaining bytes
        let remainingBytes = data.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
        data = data.dropFirst(MemoryLayout.size(ofValue: remainingBytes))
        guard data.count >= remainingBytes else {
            return nil
        }

        // Block
        guard let block = TransactionBlock(data) else {
            return nil
        }
        data = data.dropFirst(block.size)
        self.block = block
    }

    // MARK: - Instance Properties

    public let block: TransactionBlock
    public let network: BlockNetwork

    // MARK: - Computed Properties

    public var data: Data {
        var ret = Data()
        ret.addBytes(of: network.rawValue)
        ret.addBytes(of: UInt32(block.size))
        ret.append(block.data)
        return ret
    }

    /// Size of data in bytes.
    private var size: Int {
        MemoryLayout<BlockNetwork.RawValue.Type>.size + // Magic number
               MemoryLayout<UInt32>.size + // Block size
               block.size // Block
    }

    // MARK: - Instance Methods

    // MARK: - Type Properties

    // MARK: - Type Methods

    // No type methods yet.
}
