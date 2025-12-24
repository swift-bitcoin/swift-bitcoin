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

    private var fileNumber: Int {
        fileSizes.count - 1
    }

    var sizeOnDisk: Int {
        fileSizes.reduce(0, +) + undoFileSizes.reduce(0, +)
    }

    private var lastFileInfo: FileInfo? { get async throws(BlockStorageError) {
        try await fileInfo(for: fileNumber)
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

    func storeGenesisBlock(_ block: Block, undo: BlockUndo) async throws(BlockStorageError) -> BlockStorageLocator {
        if fileSizes.isEmpty {
            let locator = try await store(block)
            return try await store(undo, forBlockAt: locator)
        } else {
            return .init(file: 0, offset: 0, undoOffset: undoFileSizes.isEmpty ? -1 : 0)
        }
    }

    func store(_ block: Block) async throws(BlockStorageError) -> BlockStorageLocator {
        let fs = FileSystem.shared
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

        let path = filePath(blocksDir, for: fileNumber)
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

        // Sanity check
        /*
        if let info = try await lastFileInfo {
            logger.debug("Written file \(filePath(blocksDir, for: fileNumber).string) at offset \(offset), file size: \(info.size)")
        }
        */
        return .init(file: fileNumber, offset: Int(offset), undoOffset: -1)
    }

    func store(_ undo: BlockUndo, forBlockAt locator: BlockStorageLocator) async throws(BlockStorageError) -> BlockStorageLocator {
        precondition(locator.undoOffset == -1)
        let fs = FileSystem.shared
        let maxSize = Int64(config.maxFileSize) // Accounts for magic bytes header and block length prefix

        // Block's undo data (revert file)
        let serializedUndoBlock = undo.data

        var undoOffset: Int64

        let filePath = filePath(blocksDir, for: locator.file, undo: true)
        if undoFileSizes.indices.contains(locator.file) {
            undoOffset = Int64(undoFileSizes[locator.file])
            undoFileSizes[locator.file] += serializedUndoBlock.count
            precondition(undoFileSizes[locator.file] <= maxSize, "Undo file cannot be larger than the max block file")
        } else {
            undoOffset = 0
            undoFileSizes.append(serializedUndoBlock.count)
        }

        do {
            _ = try await fs.withFileHandle(
                forWritingAt: filePath,
                options: undoOffset == 0 ? .newFile(replaceExisting: false) : .modifyFile(createIfNecessary: false)
            ) { handle in
                try await handle.write(contentsOf: serializedUndoBlock, toAbsoluteOffset: undoOffset)
            }
        } catch {
            logger.error("Could not open block undo data file for writing.")
            throw undoOffset == 0 ? .blockFileCreateIssue : .blockFileWriteIssue
        }

        // Sanity check
        /*
        if let info = try await fileInfo(for: locator.file, undo: true) {
            logger.debug("Written undo file \(filePath) as offset \(undoOffset), file size: \(info.size)")
        }
         */
        return .init(file: locator.file, offset: locator.offset, undoOffset: Int(undoOffset))
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

        guard let locator = try? await store(genesisUndo, forBlockAt: .init(file: 0, offset: 0, undoOffset: -1)) else {
            logger.error("Could not save undo data for genesis block")
            return
        }
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

        let fs = FileSystem.shared
        let maxBlockSize = Int64(config.maxBlock + MemoryLayout<UInt32>.size * 2) // Accounts for magic bytes header and block length prefix
        let encoding = Block.Encoding.file(magicBytes: config.magic)

        logger.trace("Located block file \(locator.file) at offset \(locator.offset), file size: \(fileSizes[locator.file])")

        let blockData: [UInt8]
        do {
            blockData = try await fs.withFileHandle(forReadingAt: filePath(blocksDir, for: locator.file)) { handle in
                var reader = handle.bufferedReader(startingAtAbsoluteOffset: Int64(locator.offset), capacity: .bytes(maxBlockSize))
                var buffer = try await reader.read(.bytes(maxBlockSize))

                let lengthBytes = buffer.viewBytes(at: MemoryLayout<UInt32>.size, length: MemoryLayout<UInt32>.size)! // `at:` value accounts for network magic bytes
                let length = lengthBytes.withUnsafeBytes {
                    $0.loadUnaligned(as: UInt32.self)
                }
                return buffer.readBytes(length: Int(length))!
                // `Int(length +  MemoryLayout<UInt32>.size * 2)` could also be `newFileInfo.size - offset` which will be higher.
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

        let fs = FileSystem.shared

        // TODO: What's the max undo data size?
        let maxBlockSize = Int64(config.maxBlock + MemoryLayout<UInt32>.size) // Accounts for length prefix

        logger.trace("Located revert file \(locator.file) at \(locator.undoOffset), file size: \(undoFileSizes[locator.file])")


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
