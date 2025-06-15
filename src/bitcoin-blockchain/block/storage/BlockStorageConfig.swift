import _NIOFileSystem

struct BlockStorageConfig {
    // TODO: change default maxFileSize to 0 and let blockchain service determine it.
    init(path: FilePath? = nil, magic: Int = 0, maxBlock: Int = 0, maxFileSize: Int = 1000) {
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
