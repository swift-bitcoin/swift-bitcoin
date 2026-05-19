import BitcoinBase
import Foundation
import Collections
import Logging
import _NIOFileSystem

/// Block storage service.
actor PersistentBlockStorage: BlockStorage {

    init(config: BlockStorageConfig, logger: Logger) async throws(BlockStorageError) {
        self.config = config
        self.logger = logger

        guard let path = config.path else {
            preconditionFailure()
        }
        logger.info("Using data dir path \"\(path.string)\".")

        // Attempt to find or create the blocks subdirectory.
        let fs = FileSystem.shared
        // let currentDir = try! await fs.currentWorkingDirectory
        self.blocksDir = path.appending(config.blocksSubdirectoryName) // TODO: use config.blocksPath instead or centralize "blocks"
        logger.info("Will attempt to create \"\(blocksDir.string)\".")
        let blocksDirInfo = try? await fs.info(forFileAt: blocksDir)
        if blocksDirInfo == nil {
            do {
                try await fs.createDirectory(at: blocksDir, withIntermediateDirectories: false)
            } catch {
                logger.error("Could not create blocks subdirectory.")
                throw .dataLocationIssue
            }
        }

        // Find the last file. Careful: the value of `digits` needs to be in the regex as a literal
        let regex = /blk(\d{5})/

        let blocksDir = self.blocksDir
        var fileSizes: OrderedDictionary<Int, Int> = [:]
        var undoFileSizes: OrderedDictionary<Int, Int> = [:]
        do {
            (fileSizes, undoFileSizes) = try await fs.withDirectoryHandle(atPath: blocksDir) { [logger] dir in
                var fileSizes: OrderedDictionary<Int, Int> = [:]
                var undoFileSizes: OrderedDictionary<Int, Int> = [:]
                for try await file in dir.listContents() {
                    logger.debug("\(file.path)")
                    let name = file.name
                    let stem = name.stem
                    guard file.type == .regular, let ext = name.extension, ext == "dat", let match = try regex.wholeMatch(in: stem), let number = Int(match.output.1) else {
                        logger.trace("skiping \(name)")
                        continue
                    }
                    guard let info = try? await fs.info(forFileAt: file.path) else {
                        logger.error("Could not find the block file at \(file.path.string).")
                        throw BlockStorageError.dataLocationIssue
                    }
                    fileSizes[number] = Int(info.size)

                    if let undoInfo = try! await fs.info(forFileAt: filePath(blocksDir, for: number, undo: true)) {
                        undoFileSizes[number] = Int(undoInfo.size)
                    }

                    logger.trace("Evaluating \(name)")
                }
                return (fileSizes, undoFileSizes)
            }
        } catch let error as BlockStorageError {
            throw error
        } catch {
            logger.error("Data location issue.")
            throw .dataLocationIssue
        }
        fileSizes.sort()
        if let lastKey = fileSizes.keys.last, lastKey != fileSizes.count - 1 {
            logger.error("Missing some block data files.")
            throw .missingBlockFiles
        }
        undoFileSizes.sort()
        if let lastKey = undoFileSizes.keys.last, lastKey != undoFileSizes.count - 1 {
            logger.error("Missing some undo block data files.")
            throw .missingBlockFiles
        }
        self.fileSizes = [Int](fileSizes.values)
        self.undoFileSizes = [Int](undoFileSizes.values)

        // Initialize `lastStoredBlockFileSize` and `lastStoredUndoFileSize` for the out of band storage queue and `isCaughtUp`
        if !self.fileSizes.isEmpty {
            lastStoredBlockFileSize = (file: self.fileSizes.count - 1, size: self.fileSizes[self.fileSizes.count - 1])
        } // else { lastStoredBlockFileSize = (file: -1, size: -1) }
        if !self.undoFileSizes.isEmpty {
            lastStoredUndoFileSize = (file: self.undoFileSizes.count - 1, size: self.undoFileSizes[self.undoFileSizes.count - 1])
        } // else { lastStoredUndoFileSize = (file: -1, size: -1) }

        logger.info("Files: \(fileSizes.count), \(undoFileSizes.count); Total size: \(sizeOnDisk)")
        // TODO: Prepopulate cache with the last `Self.cacheSize` blocks.
    }

    deinit {
        // TODO: Remove our pid lock file once locking is implemented
    }

    let config: BlockStorageConfig
    let logger: Logger

    private let blocksDir: FilePath
    private var fileSizes: [Int]
    private var undoFileSizes: [Int]

    private var blockCache: OrderedDictionary<CacheKey, Block> = [:]
    private var undoCache: OrderedDictionary<CacheKey, BlockUndo> = [:]

    private var storeBlockTask = Task { }
    private var storeBlockUndoTask = Task { }
    private var lastStoredBlockFileSize = (file: -1, size: -1)
    private var lastStoredUndoFileSize = (file: -1, size: -1)

    private var lastFileNumber: Int {
        fileSizes.count - 1
    }

    var sizeOnDisk: Int {
        fileSizes.reduce(0, +) + undoFileSizes.reduce(0, +)
    }

    private var lastFileInfo: FileInfo? { get async throws(BlockStorageError) {
        try await fileInfo(for: lastFileNumber)
    } }

    private func fileInfo(for number: Int, undo: Bool = false) async throws(BlockStorageError) -> FileInfo? {
        guard number >= 0 else { return nil }
        let fs = FileSystem.shared
        let filePath = filePath(blocksDir, for: number, undo: undo)
        guard let fileInfo = try? await fs.info(forFileAt: filePath) else {
            logger.error("Could not get info for file at \(filePath.string).")
            throw .dataLocationIssue
        }
        return fileInfo
    }

    func storeGenesisBlock(_ block: Block, undo: BlockUndo) -> BlockStorageLocator {
        if fileSizes.isEmpty {
            let locator = store(block)
            return store(undo, forBlockAt: locator)
        } else {
            return .init(file: 0, offset: 0, undoOffset: undoFileSizes.isEmpty ? -1 : 0)
        }
    }

    func store(_ block: Block) -> BlockStorageLocator {
        let maxSize = Int64(config.maxFileSize) // Accounts for magic bytes header and block length prefix
        let encoding = Block.Encoding.file(magicBytes: config.magic)
        let serializedBlock = block.data(encoding: encoding)

        var offset: Int64
        if fileSizes.count == 0 || Int64(fileSizes.last!) + Int64(serializedBlock.count) > maxSize {
            offset = 0
            fileSizes.append(serializedBlock.count)
        } else {
            offset = Int64(fileSizes.last!)
            fileSizes[fileSizes.count - 1] += serializedBlock.count
        }
        let locator = BlockStorageLocator(file: lastFileNumber, offset: Int(offset), undoOffset: -1)

        blockCache[.init(locator.file, locator.offset)] = block
        if blockCache.count > maxCacheEntries {
            blockCache.removeFirst(blockCache.count - maxCacheEntries)
        }

        // Enqueue block
        let previousTask = storeBlockTask
        storeBlockTask = Task {
            await previousTask.value
            await store(serializedBlock, file: lastFileNumber, offset: offset)
        }

        return locator
    }

    func store(_ undo: BlockUndo, forBlockAt locator: BlockStorageLocator) -> BlockStorageLocator {
        precondition(locator.undoOffset == -1)

        // Block's undo data (revert file)
        let serializedUndoBlock = undo.data
        let maxSize = Int64(config.maxFileSize) // Accounts for magic bytes header and block length prefix
        var undoOffset: Int64
        if undoFileSizes.indices.contains(locator.file) {
            undoOffset = Int64(undoFileSizes[locator.file])
            undoFileSizes[locator.file] += serializedUndoBlock.count
            precondition(undoFileSizes[locator.file] <= maxSize, "Undo file cannot be larger than the max block file")
        } else {
            undoOffset = 0
            undoFileSizes.append(serializedUndoBlock.count)
        }
        let newLocator = BlockStorageLocator(file: locator.file, offset: locator.offset, undoOffset: Int(undoOffset))

        undoCache[.init(newLocator.file, newLocator.undoOffset)] = undo
        if blockCache.count > maxCacheEntries {
            blockCache.removeFirst(blockCache.count - maxCacheEntries)
        }

        // Enqueue block
        let previousTask = storeBlockUndoTask
        storeBlockUndoTask = Task {
            await previousTask.value
            await store(serializedUndoBlock, file: locator.file, offset: undoOffset, isUndo: true)
        }

        return newLocator
    }

    private func store(_ data: Data, file: Int, offset: Int64, isUndo: Bool = false) async {
        let path = filePath(blocksDir, for: file, undo: isUndo)
        let fs = FileSystem.shared
        do {
            _ = try await fs.withFileHandle(
                forWritingAt: path,
                options: offset == 0 ? .newFile(replaceExisting: false) : .modifyFile(createIfNecessary: false)
            ) { handle in
                try await handle.write(contentsOf: data, toAbsoluteOffset: offset)
            }
        } catch {
            logger.error("Could not open block data file \(path) for writing at offset \(offset): \(error).")
            // throw offset == 0 ? .blockFileCreateIssue : BlockStorageError.blockFileWriteIssue
            fatalError(error.localizedDescription)
        }
        let lastFileSize = (file, Int(offset) + data.count)
        if isUndo {
            lastStoredUndoFileSize = lastFileSize
        } else {
            lastStoredBlockFileSize = lastFileSize
        }
        // Sanity check
        /*
        if let info = try await lastFileInfo {
            logger.debug("Written file \(filePath(blocksDir, for: fileNumber).string) at offset \(offset), file size: \(info.size)")
        }
        */
    }

    private var isCaughtUp: Bool {
        lastStoredBlockFileSize.file == lastFileNumber && lastStoredBlockFileSize.size == fileSizes[lastFileNumber] &&
        lastStoredUndoFileSize.file == undoFileSizes.count - 1 && lastStoredUndoFileSize.size == undoFileSizes[undoFileSizes.count - 1]
    }

    func flush() async {
        logger.info("Flushing pending block/undo file system writes…")
        // Drain until all scheduled writes have been persisted.
        repeat { // We await at least once for tasks to complete
            // Capture current tails.
            let blockTail = storeBlockTask
            let undoTail = storeBlockUndoTask

            // Await both tails to complete.
            await withTaskGroup(of: Void.self) { g in
                g.addTask { await blockTail.value }
                g.addTask { await undoTail.value }
            }
            // Otherwise, loop again to await the new tails.
        } while !isCaughtUp
        logger.info("Flush complete: all pending writes persisted.")
    }

    func retrieve(_ locator: BlockStorageLocator) async throws(BlockStorageError) -> (Block, BlockUndo?) {
        let maxSuffix = Int(pow(Double(10), Double(digits))) - 1 // 99999
        guard locator.file >= 0, locator.file <= maxSuffix else {
            logger.error("Invalid file reference.")
            throw .invalidFileRef
        }

        let block = try await retrieveBlock(locator)
        let undo = locator.undoOffset == -1 ? nil : try await retrieveUndo(locator)
        return (block, undo)
    }

    var iterator: BlockIterator? { get async {
        guard !fileSizes.isEmpty else {
            return nil
        }
        let undoOffset = undoFileSizes.isEmpty ? -1 : 0
        let locator = BlockStorageLocator(file: 0, offset: 0, undoOffset: undoOffset)
        guard let block = try? await retrieveBlock(locator) else {
            logger.error("Could not retrieve genesis block at \(locator.file):\(locator.offset)")
            return nil
        }
        let undo: BlockUndo?
        if locator.undoOffset == -1 {
            undo = nil
        } else {
            guard let u = try? await retrieveUndo(locator) else {
                logger.error("Could not retrieve genesis block undo data at \(locator.file):\(locator.undoOffset)")
                return nil
            }
            undo = u
        }
        return .init(locator: locator, block: block, undo: undo)
    } }

    func next(_ iterator: BlockIterator) async -> BlockIterator? {
        await next(iterator, includeUndo: false)
    }

    func clearUndo() async {
        precondition(isCaughtUp, "There are pending blocks/undo data to be stored")

        guard !undoFileSizes.isEmpty, let genesisUndo = try? await retrieveUndo(.init(file: 0, offset: 0, undoOffset: 0)) else {
            logger.error("Could not find undo data for genesis block")
            return
        }

        // Find the last file. Careful: the value of `digits` needs to be in the regex as a literal
        let regex = /rev(\d{5})/

        let fs = FileSystem.shared
        let blocksDir = self.blocksDir
        try? await fs.withDirectoryHandle(atPath: blocksDir) { [logger] dir in
            for try await file in dir.listContents() {
                let name = file.name
                let stem = name.stem
                guard file.type == .regular, let ext = name.extension, ext == "dat", let match = try regex.wholeMatch(in: stem), Int(match.output.1) != nil else {
                    logger.trace("skiping \(name)")
                    continue
                }
                do {
                    try await fs.removeItem(at: file.path)
                } catch {
                    logger.error("Could not remove item at \(file.path)\n\(error)")
                }
            }
        }

        undoFileSizes = []
        undoCache = .init()

        let locator = store(genesisUndo, forBlockAt: .init(file: 0, offset: 0, undoOffset: -1))
        assert(locator == .init(file: 0, offset: 0, undoOffset: 0))
        assert(undoFileSizes.count == 1 && undoFileSizes[0] == genesisUndo.dataSize)
    }

    func next(_ iterator: BlockIterator, includeUndo: Bool) async -> BlockIterator? {
        let encoding = Block.Encoding.file(magicBytes: config.magic)

        var file = iterator.locator.file
        var offset = iterator.locator.offset + iterator.block.dataSize(encoding: encoding)
        if offset >= fileSizes[file] {
            file += 1
            offset = 0
        }
        guard file < fileSizes.count else {
            // We have reached the end of the last file
            return nil
        }

        let undoOffset: Int

        if includeUndo, let prevUndo = iterator.undo, undoFileSizes.indices.contains(file) {
            let nextUndoOffset = iterator.locator.undoOffset + prevUndo.dataSize
            if offset == 0 {
                // If the blk file increases, the rev file also increments. Offsets must both be 0.
               undoOffset = 0
            } else if nextUndoOffset < undoFileSizes[file] {
                // The offset is within the limits of the file, we can just add the size of the previous undo data to the previous offset to get the next offset
                undoOffset = nextUndoOffset
            } else {
                // The rev file does not have undo data for every block in the corresponding blk file.
                undoOffset = -1
            }
        } else {
            // Either we were asked explicitely not to include undo data, we don't have the previous undo data or the current blk file does not hava a corresponding rev file.
            undoOffset = -1
        }

        let locator = BlockStorageLocator(file: file, offset: offset, undoOffset: undoOffset)
        guard let block = try? await retrieveBlock(locator) else {
            logger.error("Could not retrieve block at \(locator.file):\(locator.offset)")
            return nil
        }
        let undo: BlockUndo?
        if locator.undoOffset == -1 {
            undo = nil
        } else {
            guard let u = try? await retrieveUndo(locator) else {
                logger.error("Could not retrieve block undo data at \(locator.file):\(locator.undoOffset)")
                return nil
            }
            undo = u
        }
        return .init(locator: locator, block: block, undo: undo)
    }

    private func retrieveBlock(_ locator: BlockStorageLocator) async throws(BlockStorageError) -> Block {
        precondition(fileSizes.indices.contains(locator.file) && locator.offset >= 0 && locator.offset < fileSizes[locator.file] )

        if let cached = blockCache[.init(locator.file, locator.offset)] {
            return cached
        }

        let maxBlockSize = Int64(config.maxBlock + MemoryLayout<UInt32>.size * 2) // Accounts for magic bytes header and block length prefix
        let encoding = Block.Encoding.file(magicBytes: config.magic)

        logger.trace("Located block file \(locator.file) at offset \(locator.offset), file size: \(fileSizes[locator.file])")

        let fs = FileSystem.shared
        let blockData: [UInt8]
        do {
            blockData = try await fs.withFileHandle(forReadingAt: filePath(blocksDir, for: locator.file)) { handle in
                var reader = handle.bufferedReader(startingAtAbsoluteOffset: Int64(locator.offset), capacity: .bytes(maxBlockSize))
                var buffer = try await reader.read(.bytes(maxBlockSize))

                let lengthBytes = buffer.viewBytes(at: MemoryLayout<UInt32>.size, length: MemoryLayout<UInt32>.size)! // `at:` value accounts for network magic bytes
                let length = lengthBytes.withUnsafeBytes {
                    $0.loadUnaligned(as: UInt32.self)
                }
                return buffer.readBytes(length: Int(length) +  MemoryLayout<UInt32>.size * 2)!
                // `Int(length) +  MemoryLayout<UInt32>.size * 2` could also be `newFileInfo.size - offset` which will be higher.
            }
        } catch {
            logger.error("There was an issue reading the file or attempting to decode block from file's data at \(locator.file):\(locator.offset)")
            throw .corruptedBlockData // TODO: Differenciate from not being able to open the file for reading.
        }
        let block: Block
        do {
            block = try Block(blockData, encoding: encoding)
        } catch {
            logger.error("There was an issue attempting to decode block from file's contents.")
            throw .corruptedBlockData
        }
        return block
    }

    private func retrieveUndo(_ locator: BlockStorageLocator) async throws(BlockStorageError) -> BlockUndo {
        precondition(locator.undoOffset != -1)
        precondition(undoFileSizes.indices.contains(locator.file) && locator.undoOffset < undoFileSizes[locator.file] )

        if let cached = undoCache[.init(locator.file, locator.undoOffset)] {
            return cached
        }

        // TODO: What's the max undo data size?
        let maxBlockSize = Int64(config.maxBlock + MemoryLayout<UInt32>.size) // Accounts for length prefix

        logger.trace("Located revert file \(locator.file) at \(locator.undoOffset), file size: \(undoFileSizes[locator.file])")

        let fs = FileSystem.shared
        let blockUndoData: [UInt8]
        do {
            blockUndoData = try await fs.withFileHandle(forReadingAt: filePath(blocksDir, for: locator.file, undo: true)) { handle in
                var reader = handle.bufferedReader(startingAtAbsoluteOffset: Int64(locator.undoOffset), capacity: .bytes(maxBlockSize))
                var buffer = try await reader.read(.bytes(maxBlockSize))
                let lengthBytes = buffer.viewBytes(at: 0, length: MemoryLayout<UInt32>.size)!
                let length = lengthBytes.withUnsafeBytes {
                    $0.loadUnaligned(as: UInt32.self)
                }
                return buffer.readBytes(length: Int(length))!
            }
        } catch {
            logger.error("There was an issue reading the file or attempting to decode block undo from file's data.")
            throw .corruptedBlockData // TODO: Differenciate from not being able to open the file for reading.
        }

        let blockUndo: BlockUndo
        do {
            blockUndo = try BlockUndo(blockUndoData)
        } catch {
            logger.error("There was an issue attempting to decode block revert information from file's contents.")
            throw .corruptedBlockData
        }
        return blockUndo
    }
}

private let blockFilePrefix = "blk"
private let undoFilePrefix = "rev"
private let digits = 5 // Warning: If this value changes, also must the `regex` local variable

private func filePath(_ base: FilePath, for number: Int, undo: Bool = false) -> FilePath {
    let formatted = String(format: "%0\(digits)d", number)
    return base.appending("\(undo ? undoFilePrefix : blockFilePrefix)\(formatted).dat")
}

private struct CacheKey: Hashable {
    init(_ file: Int, _ offset: Int) {
        self.file = file
        self.offset = offset
    }
    let file: Int
    let offset: Int
}

private let maxCacheEntries = 1000
