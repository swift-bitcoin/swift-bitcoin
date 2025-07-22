import _NIOFileSystem

struct BlockStorageConfig {
    // TODO: change default maxFileSize to 0 and let blockchain service determine it.
    init(
        path: FilePath? = nil,
        magic: Int = 0,
        maxBlock: Int = 0,
        maxFileSize: Int = 0x8000000 // 128 MiB = 134,217,728 bytes
    ) {
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
