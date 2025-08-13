import Foundation
import Collections
import Logging
import _NIOFileSystem

/// Block storage service.
actor PersistentBlockStorage: BlockStorage {

    init(config: BlockStorageConfig = .init(), logger: Logger) async throws(BlockStorageError) {
        self.config = config
        self.logger = logger

        guard let path = config.path else { return }
        logger.info("Using data dir path \"\(path.string)\".")

        // Attempt to find or create the blocks subdirectory.
        let fs = FileSystem.shared
        // let currentDir = try! await fs.currentWorkingDirectory
        let blocksDir = path.appending(config.blocksSubdirectoryName) // TODO: use config.blocksPath instead or centralize "blocks"
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

        // Save the path to the blocks dir.
        self.blocksDir = blocksDir

        // Find the last file. Careful: the value of `digits` needs to be in the regex as a literal
        let regex = /blk(\d{5})/

        let initialFileNumber = fileNumber // Will be -1
        let maxNumber: Int
        let totalFiles: Int
        let totalSize: Int
        do {
            (maxNumber, totalFiles, totalSize) = try await fs.withDirectoryHandle(atPath: blocksDir) { [logger] dir in
                var maxNumber = initialFileNumber // Will be -1
                var totalFiles = 0
                var totalSize = 0
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
                    totalSize += Int(info.size)

                    logger.trace("Evaluating \(name)")
                    maxNumber = max(number, maxNumber)
                    totalFiles += 1

                }
                return (
                    maxNumber: maxNumber,
                    totalFiles: totalFiles,
                    totalSize: totalSize
                )
            }
        } catch let error as BlockStorageError {
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

    deinit {
        // TODO: Remove our pid lock file once locking is implemented
    }

    let config: BlockStorageConfig
    let logger: Logger

    private var blocksDir = FilePath?.none
    private var fileNumber = -1

    internal private(set) var sizeOnDisk = 0

    private var lastFileInfo: FileInfo? { get async throws(BlockStorageError) {
        try await fileInfo(for: fileNumber)
    } }

    private func fileInfo(for number: Int, undo: Bool = false) async throws(BlockStorageError) -> FileInfo? {
        guard number >= 0 else { return nil }
        let fs = FileSystem.shared
        let filePath = filePath(for: number, undo: undo)
        guard let fileInfo = try? await fs.info(forFileAt: filePath) else {
            logger.error("Could not get info for file at \(filePath.string).")
            throw .dataLocationIssue
        }
        return fileInfo
    }

    func store(_ block: Block, undo: BlockUndo) async throws(BlockStorageError) -> BlockStorageLocator {
        let locator = try await store(block)
        return try await store(undo, forBlockAt: locator)
    }

    func store(_ block: Block) async throws(BlockStorageError) -> BlockStorageLocator {
        let fs = FileSystem.shared
        let maxSize = Int64(config.maxFileSize) // Accounts for magic bytes header and block length prefix

        let encoding = Block.Encoding.file(magicBytes: config.magic)
        let serializedBlock = block.data(encoding: encoding)

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
            logger.debug("Written file \(filePath(for: fileNumber).string) at offset \(offset), file size: \(info.size)")
        }
        return .init(file: fileNumber, offset: Int(offset), undoOffset: -1)
    }

    func store(_ undo: BlockUndo, forBlockAt locator: BlockStorageLocator) async throws(BlockStorageError) -> BlockStorageLocator {
        precondition(locator.undoOffset == -1)
        let fs = FileSystem.shared
        let maxSize = Int64(config.maxFileSize) // Accounts for magic bytes header and block length prefix

        // Block's undo data (revert file)
        let serializedUndoBlock = undo.data

        var undoOffset: Int64

        let filePath = filePath(for: locator.file, undo: true)
        if let info = try! await fs.info(forFileAt: filePath) {
            precondition(info.size + Int64(serializedUndoBlock.count) <= maxSize, "Undo file cannot be larger than the max block file")
            undoOffset = info.size
        } else {
            undoOffset = 0
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

        sizeOnDisk += serializedUndoBlock.count

        // Sanity check
        if let info = try await fileInfo(for: locator.file, undo: true) {
            logger.debug("Written undo file \(filePath) as offset \(undoOffset), file size: \(info.size)")
        }
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

    private func retrieveBlock(_ locator: BlockStorageLocator) async throws(BlockStorageError) -> Block {
        let fs = FileSystem.shared
        let maxBlockSize = Int64(config.maxBlock + MemoryLayout<UInt32>.size * 2) // Accounts for magic bytes header and block length prefix
        let encoding = Block.Encoding.file(magicBytes: config.magic)

        guard let info = try await fileInfo(for: locator.file) else {
            throw .invalidFileRef
        }
        logger.trace("Located block file \(locator.file) at offset \(locator.offset), file size: \(info.size)")

        let blockData: [UInt8]
        do {
            blockData = try await fs.withFileHandle(forReadingAt: filePath(for: locator.file)) { handle in
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
            logger.error("There was an issue reading the file or attempting to decode block from file's data.")
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

        let fs = FileSystem.shared

        // TODO: What's the max undo data size?
        let maxBlockSize = Int64(config.maxBlock + MemoryLayout<UInt32>.size) // Accounts for length prefix

        guard let undoInfo = try await fileInfo(for: locator.file, undo: true) else {
            throw .invalidFileRef
        }
        logger.trace("Located revert file \(locator.file) at \(locator.undoOffset), file size: \(undoInfo.size)")


        let blockUndoData: [UInt8]
        do {
            blockUndoData = try await fs.withFileHandle(forReadingAt: filePath(for: locator.file, undo: true)) { handle in
                var reader = handle.bufferedReader(startingAtAbsoluteOffset: Int64(locator.undoOffset), capacity: .bytes(maxBlockSize))
                var buffer = try await reader.read(.bytes(maxBlockSize))
                let lengthBytes = buffer.viewBytes(at: 0, length: MemoryLayout<UInt32>.size)!
                let length = lengthBytes.withUnsafeBytes {
                    $0.loadUnaligned(as: UInt32.self)
                }
                return buffer.readBytes(length: Int(length))!
            }
        } catch {
            logger.error("There was an issue reading the file or attempting to decode block from file's data.")
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

    private func filePath(for number: Int, undo: Bool = false) -> FilePath {
        guard let blocksDir else { preconditionFailure() }
        let formatted = String(format: "%0\(digits)d", number)
        return blocksDir.appending("\(undo ? undoFilePrefix : blockFilePrefix)\(formatted).dat")
    }
}

private let blockFilePrefix = "blk"
private let undoFilePrefix = "rev"
private let digits = 5 // Warning: If this value changes, also must the `regex` local variable
