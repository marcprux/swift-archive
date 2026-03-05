// swift-tools-version: 6.1

import PackageDescription

var defaultTraits: Set<String> = []

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
//defaultTraits.insert("GzipSupport")
//defaultTraits.insert("Bzip2Support")
#endif

let package = Package(
    name: "Archive",
	platforms: [.macOS(.v13), .iOS(.v15), .tvOS(.v15), .watchOS(.v10)],
    products: [
        .library(name: "Archive", targets: ["Archive"]),
    ],
    traits: [
        // On macOS, zlib and bzip2 are in the SDK. On Linux, dev packages
        // (zlib1g-dev, libbz2-dev) must be installed separately, so compression
        // traits are not enabled by default.
        .default(enabledTraits: defaultTraits),
        .trait(name: "GzipSupport", description: "Enable gzip compression (zlib)"),
        .trait(name: "Bzip2Support", description: "Enable bzip2 compression"),
        .trait(name: "XZSupport", description: "Enable xz/lzma compression (requires liblzma)"),
        .trait(name: "ZstdSupport", description: "Enable Zstandard compression (requires libzstd)"),
    ],
    targets: [
        .target(
            name: "CArchive",
            path: "libarchive",
            exclude: [ "test" ],
            publicHeadersPath: ".",
            cSettings: [
                // Android large-file support header lives in contrib/
                .headerSearchPath("../contrib/android/include", .when(platforms: [.android])),
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
				.linkedLibrary("iconv", .when(platforms: [.macOS, .iOS, .tvOS, .watchOS, .visionOS])),
                .linkedLibrary("xml2", .when(platforms: [.macOS, .iOS, .tvOS, .watchOS, .visionOS])),
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
