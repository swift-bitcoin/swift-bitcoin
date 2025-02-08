import Testing
import Foundation
import BitcoinBlockchain
import BitcoinCrypto
import BitcoinBase
import SystemPackage

struct PersistenceTests {

    @Test func persistentToMemoryBlockchainSync() async throws {
        let fm = FileManager.default
        let disambiguator = UInt.random(in: UInt.min ... UInt.max)
        let dataDirURL = fm.temporaryDirectory.appendingPathComponent("\(disambiguator)/swift-bitcoin-data")
        let dataDir = FilePath(dataDirURL.relativePath)
        try? fm.removeItem(atPath: dataDir.string)
        try fm.createDirectory(at: dataDirURL, withIntermediateDirectories: true)

        let secretKey = SecretKey()
        let pubkey = secretKey.pubkey

        let alice = BlockchainService(config: .init(dataLocation: .customDirectory(dataDir.string)))
        await alice.start()

        #expect(fm.changeCurrentDirectoryPath(dataDir.string))
        // print(dataDir.string)
        let dataDirContents = try fm.contentsOfDirectory(atPath: dataDir.string)
        #expect(dataDirContents.contains("blocks"))
        #expect(dataDirContents.contains("block-index"))
        #expect(dataDirContents.contains("headers"))
        #expect(dataDirContents.contains("coins"))

        let header1 = await alice.generateTo(pubkey)

        let bob = BlockchainService()
        await bob.start()

        try await bob.processHeaders([header1])
        await #expect(bob.height == 1)

        let bobMissingBlockIDs = await bob.getNextMissingBlocks(.max)
        #expect(bobMissingBlockIDs == [header1.id])

        let bobMissingBlocks = await alice.getBlocks(bobMissingBlockIDs)
        let bobMissingBlock = bobMissingBlocks[0]
        let block1 = try #require(await alice.getBlock(at: 1))
        #expect(bobMissingBlocks.count == 1 && bobMissingBlock == header1 && bobMissingBlock.txs == block1.txs)

        try await bob.processBlock(block1)
        await #expect(bob.validatedHeight == 1)

        await alice.stop()
        await bob.stop()

        try? fm.removeItem(atPath: dataDir.string)
    }

    @Test func memoryToPersistentBlockchainSync() async throws {
        let fm = FileManager.default
        let disambiguator = UInt.random(in: UInt.min ... UInt.max)
        let dataDirURL = fm.temporaryDirectory.appendingPathComponent("\(disambiguator)/swift-bitcoin-data")
        let dataDir = FilePath(dataDirURL.relativePath)
        try? fm.removeItem(atPath: dataDir.string)
        try fm.createDirectory(at: dataDirURL, withIntermediateDirectories: true)

        let secretKey = SecretKey()
        let pubkey = secretKey.pubkey

        let alice = BlockchainService()
        await alice.start()

        let header1 = await alice.generateTo(pubkey)

        let bob = BlockchainService(config: .init(dataLocation: .customDirectory(dataDir.string)))
        await bob.start()

        #expect(fm.changeCurrentDirectoryPath(dataDir.string))
        let dataDirContents = try fm.contentsOfDirectory(atPath: dataDir.string)
        #expect(dataDirContents.contains("blocks"))
        #expect(dataDirContents.contains("block-index"))
        #expect(dataDirContents.contains("headers"))
        #expect(dataDirContents.contains("coins"))

        try await bob.processHeaders([header1])

        await #expect(bob.height == 1)

        let bobMissingBlockIDs = await bob.getNextMissingBlocks(.max)
        #expect(bobMissingBlockIDs == [header1.id])

        let bobMissingBlocks = await alice.getBlocks(bobMissingBlockIDs)
        let bobMissingBlock = bobMissingBlocks[0]
        let block1 = try #require(await alice.getBlock(at: 1))
        #expect(bobMissingBlocks.count == 1 && bobMissingBlock == header1 && bobMissingBlock.txs == block1.txs)

        try await bob.processBlock(block1)
        await #expect(bob.validatedHeight == 1)

        await alice.stop()
        await bob.stop()

        try? fm.removeItem(atPath: dataDir.string)
    }
}
