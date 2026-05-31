# swift-libarchive

[![Build Status](https://github.com/marcprux/swift-archive/workflows/Swift%20CI/badge.svg)](https://github.com/marcprux/swift-archive/actions)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fmarcprux%2Fswift-archive%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/marcprux/swift-archive)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fmarcprux%2Fswift-archive%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/marcprux/swift-archive)

A Swift Package that compiles [libarchive](https://libarchive.org) from source and provides an idiomatic Swift API for reading and writing archive files.

[API documentation](https://swiftpackageindex.com/marcprux/swift-archive/main/documentation/archive)

## Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/libarchive/libarchive", from: "3.8.5")
]
```

Then add `"Archive"` to your target's dependencies.

## Quick Start

### Reading an archive

```swift
import Archive

// From a file
let reader = try ArchiveReader(path: "/path/to/archive.tar.gz")
try reader.forEachEntry { entry, reader in
    print(entry.pathname)
    let data = try reader.readData()
}

// From in-memory data
let reader = try ArchiveReader(data: archiveData)
let entries = try reader.listEntries()
```

### Writing an archive

```swift
import Archive

// In-memory tar.gz
let writer = try ArchiveWriter(format: .tar, filters: [.gzip])
try writer.writeEntry(
    ArchiveEntry(pathname: "hello.txt", size: Int64(data.count)),
    data: data
)
let archiveData = try writer.finish()

// Write to file
let writer = try ArchiveWriter(path: "/tmp/out.zip", format: .zip)
try writer.writeEntry(
    ArchiveEntry(pathname: "file.txt", size: Int64(data.count)),
    data: data
)
try writer.close()
```

### Extracting to disk

```swift
let reader = try ArchiveReader(data: archiveData)
try reader.extractAll(to: "/tmp/output", options: .default)
```

### Data extensions

```swift
// Compress data into an archive
let compressed = try myData.compress(as: "file.txt", format: .tar, filters: [.gzip])

// Decompress archive data
let files = try compressed.decompressArchive()  // [String: Data]

// List entries
let entries = try archiveData.archiveEntries()
```

## Supported Formats

| Format | Read | Write |
|--------|------|-------|
| tar (pax, gnutar, ustar, v7) | Yes | Yes |
| zip | Yes | Yes |
| 7-Zip | Yes | Yes |
| cpio | Yes | Yes |
| ar | Yes | Yes |
| xar | Yes | Yes |
| ISO 9660 | Yes | Yes |
| shar | No | Yes |
| mtree | Yes | Yes |
| WARC | Yes | Yes |
| RAW | Yes | Yes |
| RAR, LHA, CAB | Yes | No |

## Compression Filters

| Filter | Read | Write | Trait |
|--------|------|-------|-------|
| gzip | Yes | Yes | `GzipSupport` (default) |
| bzip2 | Yes | Yes | `Bzip2Support` (default) |
| compress | Yes | Yes | Always available |
| xz/lzma | Yes | Yes | `LZMASupport` (requires liblzma) |
| zstd | Yes | Yes | `ZstdSupport` (requires libzstd) |
| lz4 | Yes | Yes | Always available |

### Filter composition

Combine format and filters for common archive types:

```swift
// .tar.gz
try ArchiveWriter(format: .tar, filters: [.gzip])

// .tar.bz2
try ArchiveWriter(format: .tar, filters: [.bzip2])

// .tar.xz (requires LZMASupport trait)
try ArchiveWriter(format: .tar, filters: [.xz])
```

## Traits Configuration

The package uses Swift Package Manager traits to control optional compression library support:

| Trait | Default | Description |
|-------|---------|-------------|
| `GzipSupport` | Enabled | zlib (available in macOS SDK) |
| `Bzip2Support` | Enabled | bzip2 (available in macOS SDK) |
| `LZMASupport` | Disabled | Requires liblzma (e.g., `brew install xz`) |
| `ZstdSupport` | Disabled | Requires libzstd (e.g., `brew install zstd`) |

Enable additional traits:

```bash
swift build --traits LZMASupport,ZstdSupport
```

## Error Handling

All operations throw `ArchiveError` on failure:

```swift
do {
    let reader = try ArchiveReader(data: corruptData)
    _ = try reader.listEntries()
} catch let error as ArchiveError {
    print(error.code)     // libarchive errno
    print(error.message)  // Human-readable description
}
```

## Extract Options

Control extraction behavior with `ExtractOptions`:

```swift
let reader = try ArchiveReader(data: archiveData)
try reader.extractAll(to: "/tmp/out", options: [.permissions, .time, .secure])
```

Available options: `.permissions`, `.time`, `.owner`, `.acl`, `.xattr`, `.fflags`, `.noOverwrite`, `.noOverwriteNewer`, `.secure`.

## Concurrency

- `ArchiveEntry`, `ArchiveError`, `ArchiveFormat`, `ArchiveFilter`, `FileType`, and `ExtractOptions` are all `Sendable`
- `ArchiveReader` and `ArchiveWriter` are reference types (classes) that should not be shared across threads

## Architecture

The package has three targets:

1. **CArchive** — C target that compiles libarchive sources directly
2. **Archive** — Swift wrapper with idiomatic API
3. **ArchiveTests** — Tests using Swift Testing framework

## About This Fork

This repository is a purely additive fork of [libarchive/libarchive](https://github.com/libarchive/libarchive.git). No upstream files are modified, deleted, or patched; the fork only overlays the following Swift-specific additions on top of the original tree:

- `Package.swift` — Swift Package Manager manifest that compiles libarchive sources directly and declares the Swift targets and traits.
- `Sources/Archive/` — The idiomatic Swift wrapper API (`ArchiveReader`, `ArchiveWriter`, `ArchiveEntry`, etc.).
- `Sources/Cliblzma/` and `Sources/Clibzstd/` — Module maps for optional system libraries used by the `LZMASupport` and `ZstdSupport` traits.
- `Tests/ArchiveTests/` — Swift Testing-based test suite for the wrapper.
- `README-SWIFT.md` — This document.

Because the fork is strictly additive, it can be kept in sync with upstream by merging `libarchive/libarchive` directly with no conflict resolution against the C sources. The Swift overlay treats libarchive as an upstream dependency consumed in-place via SwiftPM, rather than vendoring a snapshot.

