// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Archive",
	platforms: [.macOS(.v13), .iOS(.v15), .tvOS(.v15), .watchOS(.v10)],
    products: [
        .library(name: "Archive", targets: ["Archive"]),
    ],
    traits: [
        .default(enabledTraits: ["GzipSupport", "Bzip2Support", /*"XZSupport", "ZstdSupport"*/]),
        .trait(name: "GzipSupport", description: "Enable gzip compression (zlib)"),
        .trait(name: "Bzip2Support", description: "Enable bzip2 compression"),
        .trait(name: "XZSupport", description: "Enable xz/lzma compression (requires liblzma)"),
        .trait(name: "ZstdSupport", description: "Enable Zstandard compression (requires libzstd)"),
    ],
    targets: [
        .target(
            name: "CArchive",
            path: "libarchive",
            exclude: [
                // Windows-only source files
                "archive_read_disk_windows.c",
                "archive_windows.c",
                "archive_write_disk_windows.c",
                "filter_fork_windows.c",
                // Test directory
                "test",
                // Build files
                "CMakeLists.txt",
                // Man pages
                "archive_entry_acl.3",
                "archive_entry_linkify.3",
                "archive_entry_misc.3",
                "archive_entry_paths.3",
                "archive_entry_perms.3",
                "archive_entry_stat.3",
                "archive_entry_time.3",
                "archive_entry.3",
                "archive_read_add_passphrase.3",
                "archive_read_data.3",
                "archive_read_disk.3",
                "archive_read_extract.3",
                "archive_read_filter.3",
                "archive_read_format.3",
                "archive_read_free.3",
                "archive_read_header.3",
                "archive_read_new.3",
                "archive_read_open.3",
                "archive_read_set_options.3",
                "archive_read.3",
                "archive_util.3",
                "archive_write_blocksize.3",
                "archive_write_data.3",
                "archive_write_disk.3",
                "archive_write_filter.3",
                "archive_write_finish_entry.3",
                "archive_write_format.3",
                "archive_write_free.3",
                "archive_write_header.3",
                "archive_write_new.3",
                "archive_write_open.3",
                "archive_write_set_options.3",
                "archive_write_set_passphrase.3",
                "archive_write.3",
                "cpio.5",
                "libarchive_changes.3",
                "libarchive_internals.3",
                "libarchive-formats.5",
                "libarchive.3",
                "mtree.5",
                "tar.5",
            ],
            publicHeadersPath: ".",
            cSettings: [
                .define("PLATFORM_CONFIG_H", to: "\"config_spm.h\""),
                .define("HAVE_ZLIB_H", .when(traits: ["GzipSupport"])),
                .define("HAVE_LIBZ", .when(traits: ["GzipSupport"])),
                .define("HAVE_BZLIB_H", .when(traits: ["Bzip2Support"])),
                .define("HAVE_LIBBZ2", .when(traits: ["Bzip2Support"])),
                .define("HAVE_LZMA_H", .when(traits: ["XZSupport"])),
                .define("HAVE_LIBLZMA", .when(traits: ["XZSupport"])),
                .define("HAVE_LZMA_STREAM_ENCODER_MT", .when(traits: ["XZSupport"])),
                .define("HAVE_ZSTD_H", .when(traits: ["ZstdSupport"])),
                .define("HAVE_LIBZSTD", .when(traits: ["ZstdSupport"])),
                .define("HAVE_ZSTD_compressStream", .when(traits: ["ZstdSupport"])),
                // Homebrew header paths for optional libraries
                //.unsafeFlags(["-I/opt/homebrew/include"], .when(platforms: [.macOS])),
            ],
            linkerSettings: [
                .linkedLibrary("z", .when(traits: ["GzipSupport"])),
                .linkedLibrary("bz2", .when(traits: ["Bzip2Support"])),
                .linkedLibrary("lzma", .when(traits: ["XZSupport"])),
                .linkedLibrary("zstd", .when(traits: ["ZstdSupport"])),
                .linkedLibrary("iconv"),
                .linkedLibrary("xml2", .when(platforms: [.macOS])),
                // Homebrew library paths for optional libraries
                //.unsafeFlags(["-L/opt/homebrew/lib"], .when(platforms: [.macOS])),
            ]
        ),
        .target(
            name: "Archive",
            dependencies: ["CArchive"],
            swiftSettings: [
                .define("GZIP_SUPPORT", .when(traits: ["GzipSupport"])),
                .define("BZIP2_SUPPORT", .when(traits: ["Bzip2Support"])),
                .define("XZ_SUPPORT", .when(traits: ["XZSupport"])),
                .define("ZSTD_SUPPORT", .when(traits: ["ZstdSupport"])),
            ]
        ),
        .testTarget(
            name: "ArchiveTests",
            dependencies: ["Archive"],
            swiftSettings: [
                .define("GZIP_SUPPORT", .when(traits: ["GzipSupport"])),
                .define("BZIP2_SUPPORT", .when(traits: ["Bzip2Support"])),
                .define("XZ_SUPPORT", .when(traits: ["XZSupport"])),
                .define("ZSTD_SUPPORT", .when(traits: ["ZstdSupport"])),
            ]
        ),
    ]
)
