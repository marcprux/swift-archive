import CArchive

/// Supported archive compression filters.
public enum ArchiveFilter: Sendable {
    case none
    case gzip
    case bzip2
    case compress
    case lzma
    case xz
    case lz4
    case zstd

    /// Adds this filter to an archive write handle.
    internal func addWriteFilter(_ a: OpaquePointer) -> Int32 {
        switch self {
        case .none: return archive_write_add_filter_none(a)
        case .gzip: return archive_write_add_filter_gzip(a)
        case .bzip2: return archive_write_add_filter_bzip2(a)
        case .compress: return archive_write_add_filter_compress(a)
        case .lzma: return archive_write_add_filter_lzma(a)
        case .xz: return archive_write_add_filter_xz(a)
        case .lz4: return archive_write_add_filter_lz4(a)
        case .zstd: return archive_write_add_filter_zstd(a)
        }
    }
}
