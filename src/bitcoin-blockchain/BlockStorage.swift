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

        let blocksSubdirectoryName = "blocks"
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

    private var blocksDir = FilePath?.none
    private var fileNumber = -1

    private var cache = OrderedDictionary<Locator, TxBlock>()

    private var blocks = [TxBlock]() // Use only for in-memory

    internal private(set) var sizeOnDisk = 0

    func start() async throws(Error) {
        status = .starting
        defer { status = .running }
        guard let path = config.path else { return }
        logger.info("Using data dir path \"\(path.string)\".")

        // Attempt to find or create the blocks subdirectory.
        let fs = FileSystem.shared
        // let currentDir = try! await fs.currentWorkingDirectory
        let blocksDir = path.appending(config.blocksSubdirectoryName) // TODO: use config.blocksPath instead or centralize "blocks"
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

        // Save the path to the blocks dir.
        self.blocksDir = blocksDir

        // Find the last file.
        let initialFileNumber = fileNumber // Will be -1
        let maxNumber: Int
        let totalFiles: Int
        let totalSize: Int
        do {
            (maxNumber, totalFiles, totalSize) = try await fs.withDirectoryHandle(atPath: blocksDir) { dir in
                var maxNumber = initialFileNumber // Will be -1
                var totalFiles = 0
                var totalSize = 0
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
                    guard let info = try? await fs.info(forFileAt: file.path) else {
                        logger.error("Could not find the file at \(file.path.string).")
                        throw Error.dataLocationIssue
                    }
                    totalSize += Int(info.size)

                    logger.debug("Evaluating \(name)")
                    maxNumber = max(number, maxNumber)
                    totalFiles += 1

                }
                return (
                    maxNumber: maxNumber,
                    totalFiles: totalFiles,
                    totalSize: totalSize
                )
            }
        } catch let error as Error {
            throw error
        } catch {
            logger.error("Data location issue.")
            throw .dataLocationIssue
        }
        logger.debug("Max number: \(maxNumber)")
        logger.debug("Total files: \(totalFiles)")
        logger.info("Total size: \(totalSize)")
        guard maxNumber == totalFiles - 1 else {
            logger.error("Missing some block data files.")
            throw .missingBlockFiles
        }
        fileNumber = maxNumber
        self.sizeOnDisk = totalSize

        // TODO: Prepopulate cache with the last `Self.cacheSize` blocks.
    }

    var lastFileInfo: FileInfo? { get async throws(Error) {
        try await fileInfo(for: fileNumber)
    } }

    func fileInfo(for number: Int) async throws(Error) -> FileInfo? {
        guard number >= 0 else { return .none }
        let fs = FileSystem.shared
        let filePath = filePath(for: number)
        guard let fileInfo = try? await fs.info(forFileAt: filePath) else {
            logger.error("Could not find the file at \(filePath.string).")
            throw .dataLocationIssue
        }
        return fileInfo
    }

    func stop() {
        status = .stopping
        // TODO: Remove our pid lock file once locking is implemented
        status = .stopped
    }

    func store(_ block: TxBlock) async throws(Error) -> Locator {
        let locator: Locator
        if config.path == .none {
            locator = .init(file: -1, offset: blocks.endIndex)
            blocks.append(block)
        } else {
            locator = try await storeToDisk(block)
        }
        if cache.count == Self.cacheSize - 1 {
            cache.removeFirst()
        }
        cache[locator] = block
        return locator
    }

    private func storeToDisk(_ block: TxBlock) async throws(Error) -> Locator {
        let fs = FileSystem.shared
        let maxSize = Int64(config.maxFileSize) // Accounts for magic bytes header and block length prefix
        let encoding = TxBlock.Encoding.file(magicBytes: config.magic)

        let serializedBlock = block.binaryData(encoding: encoding)

        var offset: Int64
        if let info = try await lastFileInfo, info.size + Int64(serializedBlock.count) <= maxSize {
            offset = info.size
        } else {
            offset = 0
            fileNumber += 1
        }

        let path = filePath(for: fileNumber)
        do {
            _ = try await fs.withFileHandle(
                forWritingAt: path,
                options: offset == 0 ? .newFile(replaceExisting: false) : .modifyFile(createIfNecessary: false)
            ) { handle in
                try await handle.write(contentsOf: serializedBlock, toAbsoluteOffset: offset)
            }
        } catch {
            logger.error("Could not open block data file for writing.")
            throw offset == 0 ? .blockFileCreateIssue : .blockFileWriteIssue
        }

        sizeOnDisk += serializedBlock.count

        // Sanity check
        if let info = try await lastFileInfo {
            logger.debug("Written file \(filePath(for: fileNumber).string) as offset \(offset), file size: \(info.size)")
        }
        return .init(file: fileNumber, offset: Int(offset))
    }

    func retrieve(_ locator: Locator) async throws(Error) -> TxBlock? {
        if let block = cache[locator] {
            return block
        }
        return if config.path == .none {
            blocks[locator.offset]
        } else {
            try await retrieveFromDisk(locator)
        }
    }

    private func retrieveFromDisk(_ locator: Locator) async throws(Error) -> TxBlock? {
        let fs = FileSystem.shared
        let maxBlockSize = Int64(config.maxBlock + MemoryLayout<UInt32>.size * 2) // Accounts for magic bytes header and block length prefix
        let encoding = TxBlock.Encoding.file(magicBytes: config.magic)

        // TODO: Make 99999999 dependant on the digits of the number portion of the file name currently 8.
        guard locator.file >= 0, locator.file <= 99999999 else {
            logger.error("Invalid file reference.")
            throw .invalidFileRef
        }

        guard let info = try await fileInfo(for: locator.file) else {
            throw .invalidFileRef
        }
        logger.debug("Located file \(locator.file) as offset \(locator.offset), file size: \(info.size)")

        let blockData: [UInt8]
        do {
            blockData = try await fs.withFileHandle(forReadingAt: filePath(for: locator.file)) { handle in
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

    private func filePath(for number: Int) -> FilePath {
        guard let blocksDir else { preconditionFailure() }
        let formatted = String(format: "%08d", number)
        return blocksDir.appending("\(formatted).dat")
    }

    static let cacheSize = 3
}

extension BlockStorage.Locator: BinaryCodable {
    init(from decoder: inout BinaryDecoder) throws(BinaryDecodingError) {
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
