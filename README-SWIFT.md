# swift-libarchive

[![Build Status](https://github.com/marcprux/swift-archive/workflows/Swift%20CI/badge.svg)](https://github.com/marcprux/swift-archive/actions)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fmarcprux%2Fswift-archive%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/marcprux/swift-archive)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fmarcprux%2Fswift-archive%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/marcprux/swift-archive)

A Swift Package that compiles [libarchive](https://libarchive.org) from source and provides an idiomatic Swift API for reading and writing archive files.

[API documentation](https://swiftpackageindex.com/marcprux/swift-archive/swift/documentation/archive)

## Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/marcprux/swift-archive", from: "3.8.6")
]
```

> Depend on `marcprux/swift-archive`, **not** `libarchive/libarchive` — only this fork's
> release tags carry the `Package.swift` manifest that SwiftPM needs. See
> [Synchronizing Releases with Upstream](#synchronizing-releases-with-upstream) for how
> those tags are produced.

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

## Synchronizing Releases with Upstream

This fork tracks [libarchive/libarchive](https://github.com/libarchive/libarchive) and
republishes each upstream release **under the same version number**, with the Swift overlay
added. The model has three moving parts:

- The **`swift` branch** is the integration branch: the upstream tree plus the additive Swift
  overlay (`Package.swift`, `Sources/`, `Tests/`, the `Cliblzma`/`Clibzstd` module maps,
  `libarchive/config_spm.h`, `.spi.yml`, `swift-ci.yml`, and this `README-SWIFT.md`). Because
  the overlay only *adds* files and never edits upstream sources, merging upstream is
  conflict-free.
- A **release tag `vX.Y.Z`** reuses upstream's exact version number, but points at a commit on
  the `swift` branch — i.e. one that contains `Package.swift`. That is what makes it resolvable
  by SwiftPM from `marcprux/swift-archive`.
- This repository also **mirrors upstream's own `vX.Y.Z` tags**, which point at pure-upstream
  "Release X.Y.Z" commits that have **no `Package.swift`**. The fork's release tag therefore has
  to *override* the same-named upstream tag — that is what the force-push in step 2 does.

> ⚠️ **The invariant that must always hold:** a release tag must point at a commit that contains
> `Package.swift`. If a `vX.Y.Z` tag is left pointing at the upstream "Release X.Y.Z" commit,
> `swift package resolve` against this repo fails because that commit has no manifest.

### Automated: `Scripts/swift-release.sh`

The whole flow is scripted. To mirror a specific upstream release:

```bash
Scripts/swift-release.sh 3.8.7
```

To release whatever the **most recent upstream release tag** is, run it with no argument:

```bash
Scripts/swift-release.sh
```

Useful flags: `--dry-run` (print the plan and resolved version without changing anything),
`--no-test`, `--no-release` (tag only), `-y`/`--yes` (skip the confirmation prompt), `--help`.
The script performs exactly the manual steps below, and refuses to publish a tag whose commit
does not contain `Package.swift`.

The manual steps are documented here as the reference the script implements.

### One-time setup

```bash
git remote add upstream https://github.com/libarchive/libarchive.git
```

### 1. Sync upstream history into the `swift` branch

```bash
git fetch upstream --tags
git checkout swift
git merge --no-edit upstream/master   # additive overlay → no conflicts
swift build && swift test             # confirm the Swift package still builds
git push origin swift
```

### 2. Cut a release that mirrors an upstream version

Pick the upstream version to mirror (e.g. `3.8.7`). Upstream cuts patch releases from its
`patch/3.x` branches rather than `master`, so merge the **tag** (not just `upstream/master`) to
be sure the release-specific fixes are included:

```bash
VERSION=3.8.7

git fetch upstream --tags
git checkout swift
git merge --no-edit "v$VERSION"       # additive overlay → no conflicts
swift build && swift test
git push origin swift

# Tag the overlay commit with the upstream version, overriding the mirrored upstream tag:
git tag -f -a "v$VERSION" -m "libarchive $VERSION + Swift overlay"
git push origin -f "v$VERSION"        # force: replaces the upstream-mirrored tag of the same name
```

Confirm the tag is SwiftPM-consumable **before** announcing it:

```bash
git ls-tree --name-only "v$VERSION" | grep -qx 'Package.swift' \
  && echo "OK: v$VERSION includes Package.swift" \
  || echo "ERROR: v$VERSION has no Package.swift — do not release"
```

### 3. Publish the GitHub release

```bash
gh release create "v$VERSION" \
  --repo marcprux/swift-archive \
  --title "v$VERSION" \
  --notes "Based on libarchive $VERSION with the Swift Package overlay."
```

### Fixing a release that points at the wrong commit

If a tag/release already points at a pure-upstream commit (no `Package.swift` — as `v3.8.5` and
`v3.8.7` once did), delete it and re-cut it onto the overlay:

```bash
VERSION=3.8.7
gh release delete "v$VERSION" --repo marcprux/swift-archive --yes --cleanup-tag
# then repeat steps 2–3 above
```

### Release checklist

- [ ] `git ls-tree v$VERSION` lists `Package.swift`
- [ ] `swift build` and `swift test` pass at the tagged commit
- [ ] A throwaway package depending on `marcprux/swift-archive` with `from: "$VERSION"` resolves
      to the new tag (`swift package resolve`)
- [ ] The GitHub release for `v$VERSION` is marked **Latest**

## About This Fork

This repository is a purely additive fork of [libarchive/libarchive](https://github.com/libarchive/libarchive.git). No upstream files are modified, deleted, or patched; the fork only overlays the following Swift-specific additions on top of the original tree:

- `Package.swift` — Swift Package Manager manifest that compiles libarchive sources directly and declares the Swift targets and traits.
- `Sources/Archive/` — The idiomatic Swift wrapper API (`ArchiveReader`, `ArchiveWriter`, `ArchiveEntry`, etc.).
- `Sources/Cliblzma/` and `Sources/Clibzstd/` — Module maps for optional system libraries used by the `LZMASupport` and `ZstdSupport` traits.
- `Tests/ArchiveTests/` — Swift Testing-based test suite for the wrapper.
- `Scripts/swift-release.sh` — Automates merging an upstream release tag and publishing the version-matched Swift release (see [Synchronizing Releases with Upstream](#synchronizing-releases-with-upstream)).
- `README-SWIFT.md` — This document.

Because the fork is strictly additive, it can be kept in sync with upstream by merging `libarchive/libarchive` directly with no conflict resolution against the C sources. The Swift overlay treats libarchive as an upstream dependency consumed in-place via SwiftPM, rather than vendoring a snapshot. See [Synchronizing Releases with Upstream](#synchronizing-releases-with-upstream) for the exact workflow used to merge upstream and publish version-matched releases.

