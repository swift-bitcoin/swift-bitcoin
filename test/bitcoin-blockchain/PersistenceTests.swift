import Testing
import Foundation
import BitcoinBlockchain
import BitcoinCrypto
import BitcoinBase
import SystemPackage

struct PersistenceTests {

    @Test func persistentToMemoryBlockchainSync() async throws {
        await withKnownIssue("Some blockchain persistence tests randomly crashing after NIO update #451", isIntermittent: true) {
            let fm = FileManager.default
            let disambiguator = UInt.random(in: UInt.min ... UInt.max)
            let dataDirURL = fm.temporaryDirectory.appendingPathComponent("\(disambiguator)/swift-bitcoin-data")
            let dataDir = FilePath(dataDirURL.relativePath)
            try? fm.removeItem(atPath: dataDir.string)
            try fm.createDirectory(at: dataDirURL, withIntermediateDirectories: true)

            let secretKey = SecretKey()
            let pubkey = secretKey.pubkey

            let alice = try await BlockchainService(config: .init(dataLocation: .custom(path: dataDir.string)))

            // print(dataDir.string)
            let dataDirContents = try fm.contentsOfDirectory(atPath: dataDir.string)
            #expect(dataDirContents.contains("blocks"))
            #expect(dataDirContents.contains("block-index"))
            #expect(dataDirContents.contains("coins"))

            let header1 = try #require(await alice.generateTo(pubkey))

            let bob = try await BlockchainService()

            try await bob.processHeaders([header1.header])
            await #expect(bob.headers == 1)

            let bobMissingBlockIDs = await bob.getNextMissingBlocks(.max)
            #expect(bobMissingBlockIDs == [header1.id])

            let bobMissingBlocks = await alice.getBlocks(bobMissingBlockIDs)
            let bobMissingBlock = bobMissingBlocks[0]
            let block1 = try #require(await alice.getBlock(at: 1))
            #expect(bobMissingBlocks.count == 1 && bobMissingBlock == header1 && bobMissingBlock.txs == block1.txs)

            try await bob.processBlock(block1)
            await #expect(bob.height == 1)

            try? fm.removeItem(atPath: dataDir.string)
        }
    }

    @Test func memoryToPersistentBlockchainSync() async throws {
        await withKnownIssue("Some blockchain persistence tests randomly crashing after NIO update #451", isIntermittent: true) {

            let fm = FileManager.default
            let disambiguator = UInt.random(in: UInt.min ... UInt.max)
            let dataDirURL = fm.temporaryDirectory.appendingPathComponent("\(disambiguator)/swift-bitcoin-data")
            let dataDir = FilePath(dataDirURL.relativePath)
            try? fm.removeItem(atPath: dataDir.string)
            try fm.createDirectory(at: dataDirURL, withIntermediateDirectories: true)

            let secretKey = SecretKey()
            let pubkey = secretKey.pubkey

            let alice = try await BlockchainService()

            let header1 = try #require(await alice.generateTo(pubkey))

            let bob = try await BlockchainService(config: .init(dataLocation: .custom(path: dataDir.string)))

            let dataDirContents = try fm.contentsOfDirectory(atPath: dataDir.string)
            #expect(dataDirContents.contains("blocks"))
            #expect(dataDirContents.contains("block-index"))
            #expect(dataDirContents.contains("coins"))

            try await bob.processHeaders([header1.header])

            await #expect(bob.headers == 1)

            let bobMissingBlockIDs = await bob.getNextMissingBlocks(.max)
            #expect(bobMissingBlockIDs == [header1.id])

            let bobMissingBlocks = await alice.getBlocks(bobMissingBlockIDs)
            let bobMissingBlock = bobMissingBlocks[0]
            let block1 = try #require(await alice.getBlock(at: 1))
            #expect(bobMissingBlocks.count == 1 && bobMissingBlock == header1 && bobMissingBlock.txs == block1.txs)

            try await bob.processBlock(block1)
            await #expect(bob.height == 1)

            try! fm.removeItem(atPath: dataDir.string)
        }
    }
}
