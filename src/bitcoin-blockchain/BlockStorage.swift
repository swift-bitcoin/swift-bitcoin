import Foundation
import BitcoinCrypto
import Collections
import Logging
import _NIOFileSystem

private let logger = Logger(label: "swift-bitcoin.block-storage")

/// Block storage service.
actor BlockStorage {

    struct Locator: Hashable {
        let file: Int
        let offset: Int
    }

    struct Config {
        // TODO: change default maxFileSize to 0 and let blockchain service determine it.
        init(path: FilePath? = .none, magic: Int = 0, maxBlock: Int = 0, maxFileSize: Int = 1000) {
            self.path = path
            self.magic = magic
            self.maxBlock = maxBlock
            self.maxFileSize = maxFileSize
        }
        
        let path: FilePath?
        let magic: Int
        let maxBlock: Int

        // In bytes.
        let maxFileSize: Int

        var blocksPath: FilePath? {
            path?.appending("blocks")
        }
    }

    enum Status {
        case idle, starting, running, stopping, stopped
    }

    enum Error: Swift.Error {
        case dataLocationIssue, missingBlockFiles, blockFileReadIssue, blockFileWriteIssue, blockFileCreateIssue, corruptedBlockData, invalidFileRef
    }

    init(config: Config = .init()) {
        self.config = config
    }

    let config: Config
    internal private(set) var status = Status.idle

    // TODO: do we need to maintain all of these?
    private var maxNumber = -1
    private var lastFile: FilePath?
    private var lastFileSize: Int64?

    private var cache = OrderedDictionary<Locator, TxBlock>()

    private var blocks = [TxBlock]() // Use only for in-memory

    func start() async throws(Error) {
        status = .starting
        defer { status = .running }
        guard let path = config.path else { return }
        logger.info("Using path \"\(path.string)\".")

        // Change to provided path, i.e. the node's data directory path.
        let fm = FileManager.default
        guard fm.changeCurrentDirectoryPath(path.string) else {
            logger.error("Could not change directories to the configured path.")
            throw .dataLocationIssue
        }

        // Attempt to find or create the blocks subdirectory.
        let fs = FileSystem.shared
        let currentDir = try! await fs.currentWorkingDirectory
        let blocksDir = path.appending("blocks") // TODO: use config.blocksPath instead
        logger.info("Will attempt to create \"\(blocksDir.string)\".")
        let blocksDirInfo = try? await fs.info(forFileAt: blocksDir)
        if blocksDirInfo == .none {
            do {
                try await fs.createDirectory(at: blocksDir, withIntermediateDirectories: false)
            } catch {
                logger.error("Could not create blocks subdirectory.")
                throw .dataLocationIssue
            }
        }

        // Find the last file.
        let initialMaxNumber = maxNumber // Will be -1
        let (maxNumber, totalFiles) = try! await fs.withDirectoryHandle(atPath: currentDir) { dir in
            var maxNumber = initialMaxNumber
            var totalFiles = 0
            for try await file in dir.listContents() {
                logger.debug("\(file.path)")
                let name = file.name
                let stem = name.stem
                let digits = /\d{8}/
                let match = try digits.wholeMatch(in: stem)
                guard file.type == .regular, let ext = name.extension, ext == "dat", match != nil, let number = Int(stem) else {
                    logger.debug("skiping \(name)")
                    continue
                }
                logger.debug("Evaluating \(name)")
                maxNumber = max(number, maxNumber)
                totalFiles += 1
            }
            return (
                maxNumber: maxNumber,
                totalFiles: totalFiles
            )
        }
        logger.debug("Max number: \(maxNumber)")
        logger.debug("Total files: \(totalFiles)")
        guard maxNumber == totalFiles - 1 else {
            logger.error("Missing block data files.")
            throw .missingBlockFiles
        }
        self.maxNumber = maxNumber

        if maxNumber >= 0 {
            lastFile = currentDir.appending(makeFileName(maxNumber))
            guard let lastFileInfo = try? await fs.info(forFileAt: lastFile!) else {
                logger.error("Could not find the last file.")
                throw .dataLocationIssue
            }
            lastFileSize = lastFileInfo.size
            logger.debug("Last file \(lastFile!) size: \(lastFileSize!)")
        } else {
            lastFile = .none
            lastFileSize = .none
        }
    }

    func stop() {
        status = .stopping
        // TODO: Remove lock file?
        status = .stopped
    }

    func store(_ block: TxBlock) async throws(Error) -> Locator {
        let locator: Locator
        if let path = config.blocksPath {
            locator = try await storeToDisk(block, path: path)
        } else {
            locator = .init(file: -1, offset: blocks.endIndex)
            blocks.append(block)
        }
        if cache.count == Self.cacheSize - 1 {
            cache.removeFirst()
        }
        cache[locator] = block
        return locator
    }

    private func storeToDisk(_ block: TxBlock, path: FilePath) async throws(Error) -> Locator {

        // Change to provided path, i.e. the node's data directory path.
        let fm = FileManager.default
        guard fm.changeCurrentDirectoryPath(path.string) else {
            logger.error("Could not change directories to the configured path.")
            throw .dataLocationIssue
        }

        let fs = FileSystem.shared
        let currentDir = try! await fs.currentWorkingDirectory

        let maxSize = Int64(config.maxFileSize) // Accounts for magic bytes header and block length prefix

        let encoding = TxBlock.Encoding.file(magicBytes: config.magic)

        var file: FilePath
        var offset: Int64
        if let lastFile, let lastFileSize, lastFileSize + Int64(block.binarySize(encoding: encoding)) <= maxSize {
            file = lastFile
            offset = lastFileSize
            do {
            _ = try await fs.withFileHandle(forWritingAt: file, options: .modifyFile(createIfNecessary: false)) { handle in
                try await handle.write(contentsOf: block.binaryData(encoding: encoding), toAbsoluteOffset: offset)
            }
            } catch {
                logger.error("Could not open block data file for modifying.")
                throw .blockFileWriteIssue
            }
        } else {
            let newMaxNumber = maxNumber + 1
            file = currentDir.appending(makeFileName(newMaxNumber))
            offset = 0
            do {
                _ = try await fs.withFileHandle(forWritingAt: file, options: .newFile(replaceExisting: false)) { handle in
                    try await handle.write(contentsOf: block.binaryData(encoding: encoding), toAbsoluteOffset: offset)
                }
            } catch {
                logger.error("Could not create block data file.")
                throw .blockFileCreateIssue
            }
            maxNumber = newMaxNumber
        }

        let fileInfo: FileInfo?
        do {
            fileInfo = try await fs.info(forFileAt: file)
        } catch {
            logger.error("Could not read block data file.")
            throw .blockFileCreateIssue
        }
        guard let fileInfo else {
            logger.error("Could not read block data file.")
            throw .blockFileCreateIssue
        }
        logger.debug("Written file \(file) as offset \(offset), file size: \(fileInfo.size)")
        return .init(file: maxNumber, offset: Int(offset))
    }

    func retrieve(_ locator: Locator) async throws(Error) -> TxBlock? {
        if let block = cache[locator] {
            return block
        }
        return if let path = config.blocksPath {
            try await retrieveFromDisk(locator, path: path)
        } else {
            blocks[locator.offset]
        }
    }

    private func retrieveFromDisk(_ locator: Locator, path: FilePath) async throws(Error) -> TxBlock? {

        // Change to provided path, i.e. the node's data directory path.
        let fm = FileManager.default
        guard fm.changeCurrentDirectoryPath(path.string) else {
            logger.error("Could not change directories to the configured path.")
            throw .dataLocationIssue
        }

        let fs = FileSystem.shared
        let currentDir = try! await fs.currentWorkingDirectory

        let maxBlockSize = Int64(config.maxBlock + MemoryLayout<UInt32>.size * 2) // Accounts for magic bytes header and block length prefix

        let encoding = TxBlock.Encoding.file(magicBytes: config.magic)

        // TODO: Make 99999999 dependant on the digits of the number portion of the file name currently 8.
        guard locator.file >= 0, locator.file >= 99999999 else {
            logger.error("Invalid file reference.")
            throw .invalidFileRef
        }
        let file = currentDir.appending(makeFileName(locator.file))


        let fileInfo: FileInfo?
        do {
            fileInfo = try await fs.info(forFileAt: file)
        } catch {
            logger.error("Could not read block data file.")
            throw .blockFileReadIssue
        }
        guard let fileInfo else {
            logger.error("Could not access block data file info.")
            throw .blockFileReadIssue
        }
        logger.debug("Located file \(file) as offset \(locator.offset), file size: \(fileInfo.size)")

        let blockData: [UInt8]

        do {
            blockData = try await fs.withFileHandle(forReadingAt: file) { handle in
                var buffer = try await handle.readToEnd(fromAbsoluteOffset: Int64(locator.offset), maximumSizeAllowed: .bytes(maxBlockSize))

                let lengthBytes = buffer.viewBytes(at: MemoryLayout<UInt32>.size, length: MemoryLayout<UInt32>.size)!
                let length = lengthBytes.withUnsafeBytes {
                    $0.loadUnaligned(as: UInt32.self)
                }
                return buffer.readBytes(length: MemoryLayout<UInt32>.size * 2 + Int(length))!
                // `Int(length +  MemoryLayout<UInt32>.size * 2)` could also be `newFileInfo.size - offset` which will be higher.
            }
        } catch {
            logger.error("There was an issue reading the file or attempting to decode block from file's data.")
            throw .corruptedBlockData // TODO: Differenciate from not being able to open the file for reading.
        }
        do {
            return try TxBlock(binaryData: blockData, encoding: encoding)
        } catch {
            logger.error("There was an issue attempting to decode block from file's data.")
            throw .corruptedBlockData
        }
    }


    func remove(_ locator: Locator) {
        // We don't remove blocks from actual storage. The index will get marked as stale outside of this actor. We will just remove from the cache.
        cache.removeValue(forKey: locator)
    }

    static let cacheSize = 3
}

extension BlockStorage.Locator: BinaryCodable {
    init(from decoder: inout BinaryDecoder) throws {
        file = try decoder.decode()
        offset = try decoder.decode()
    }
    
    func encode(to encoder: inout BinaryEncoder) {
        encoder.encode(file)
        encoder.encode(offset)
    }
    
    func encodingSize(_ counter: inout BinaryEncodingSizeCounter) {
        counter.count(Int.self)
        counter.count(Int.self)
    }
}

private func makeFileName(_ number: Int) -> FilePath.Component {
    let formatted = String(format: "%08d", number)
    return .init("\(formatted).dat")!
}
