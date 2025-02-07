import Collections
import _NIOFileSystem

/// Block storage service.
actor BlockStorage {

    typealias Locator = [TxBlock].Index

    let folder: FilePath?
    private let fileSystem = FileSystem.shared

    private var cache = OrderedDictionary<Locator, TxBlock>()
    private var blocks = [TxBlock]()

    init(folder: FilePath? = .none) {
        self.folder = folder
    }

    func start() async {
        if let folder {

// Files can be inspected by using 'info':

            if let info = try? await fileSystem.info(forFileAt: folder) {
                if info.type != .directory {
                    // Error: folder is actually a regular file, not a directory
                    try? await fileSystem.withDirectoryHandle(atPath: folder) { directory in
                        var lastFile: FilePath
                        do {
                            for try await file in directory.listContents() {
                                lastFile = file.path
                            }
                        } catch {
                            return
                        }
                    }
                }

              print("demise-of-dave.txt has type '\(info.type)'")
            } else {
              // Error: folder does not exist
            }

        }
    }

    func store(_ block: TxBlock) -> Locator {
        let locator = blocks.endIndex
        blocks.append(block)
        if cache.count == Self.cacheSize - 1 {
            cache.removeFirst()
        }
        cache[locator] = block
        return locator
    }

    func store(_ block: TxBlock, at locator: Locator) {
        blocks[locator] = block
        if cache[locator] != nil {
            cache[locator] = block
        }
    }

    func retrieve(_ locator: Locator) -> TxBlock {
        if let block = cache[locator] {
            return block
        }
        return blocks[locator]
    }

    func remove(_ locator: Locator) {
        blocks.remove(at: locator)
        cache.removeValue(forKey: locator)
    }

    static let cacheSize = 3
}
