//
//  AtriaArchive.swift
//

import Foundation

/// Lightweight single-file archive format for .atria packages.
///
/// Binary layout:
///   [8]  magic   "ATRIA001"
///   [2]  version UInt16 big-endian (= 1)
///   [4]  count   UInt32 big-endian  — number of files
///   [count × TOC entries]
///     [2]  pathLen  UInt16 big-endian
///     [pathLen] path  UTF-8, relative (e.g. "Echo/image.dcm")
///     [8]  offset   UInt64 big-endian — byte offset of data in the file
///     [8]  size     UInt64 big-endian — byte length of data
///   [file data — concatenated raw bytes]
enum AtriaArchive {

    private static let magic = Data("ATRIA001".utf8)
    private static let chunkSize = 4 * 1024 * 1024  // 4 MB read/write chunks

    // MARK: - Write (macOS)

    static func write(from sourceDir: URL, to destination: URL) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: destination.path) {
            try fm.removeItem(at: destination)
        }

        guard let enumerator = fm.enumerator(
            at: sourceDir,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        var entries: [(relativePath: String, url: URL, size: UInt64)] = []
        for case let url as URL in enumerator {
            let vals = try url.resourceValues(forKeys: [.isRegularFileKey])
            guard vals.isRegularFile == true else { continue }
            let rel = String(url.path.dropFirst(sourceDir.path.count + 1))
            let size = UInt64((try fm.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0)
            entries.append((relativePath: rel, url: url, size: size))
        }

        // Compute TOC size so data offsets can be pre-calculated.
        let headerSize = 8 + 2 + 4
        var tocSize = 0
        for e in entries { tocSize += 2 + e.relativePath.utf8.count + 8 + 8 }
        var currentOffset = UInt64(headerSize + tocSize)

        // Build header + TOC in memory (small — only paths + offsets).
        var header = Data()
        header.append(magic)
        header.appendUInt16(1)
        header.appendUInt32(UInt32(entries.count))
        for e in entries {
            let pathBytes = Data(e.relativePath.utf8)
            header.appendUInt16(UInt16(pathBytes.count))
            header.append(pathBytes)
            header.appendUInt64(currentOffset)
            header.appendUInt64(e.size)
            currentOffset += e.size
        }

        fm.createFile(atPath: destination.path, contents: nil)
        let out = try FileHandle(forWritingTo: destination)
        defer { try? out.close() }
        out.write(header)

        // Stream each file in chunks.
        for e in entries {
            let src = try FileHandle(forReadingFrom: e.url)
            defer { try? src.close() }
            var remaining = e.size
            while remaining > 0 {
                let toRead = Int(min(remaining, UInt64(chunkSize)))
                let chunk = src.readData(ofLength: toRead)
                out.write(chunk)
                remaining -= UInt64(chunk.count)
            }
        }
    }

    // MARK: - Read

    static func extract(_ archiveURL: URL, to destinationDir: URL) throws {
        let fm = FileManager.default
        let handle = try FileHandle(forReadingFrom: archiveURL)
        defer { try? handle.close() }

        let magicBytes = handle.readData(ofLength: 8)
        guard magicBytes == magic else { throw CocoaError(.fileReadCorruptFile) }

        _ = handle.readBigEndianUInt16()   // version
        let count = Int(handle.readBigEndianUInt32())

        struct Entry { let path: String; let offset: UInt64; let size: UInt64 }
        var entries: [Entry] = []
        entries.reserveCapacity(count)
        for _ in 0..<count {
            let pathLen = Int(handle.readBigEndianUInt16())
            let pathData = handle.readData(ofLength: pathLen)
            let path = String(bytes: pathData, encoding: .utf8) ?? ""
            let offset = handle.readBigEndianUInt64()
            let size   = handle.readBigEndianUInt64()
            entries.append(Entry(path: path, offset: offset, size: size))
        }

        try fm.createDirectory(at: destinationDir, withIntermediateDirectories: true)
        for e in entries {
            let dest = destinationDir.appendingPathComponent(e.path)
            try fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
            try handle.seek(toOffset: e.offset)
            fm.createFile(atPath: dest.path, contents: nil)
            let out = try FileHandle(forWritingTo: dest)
            defer { try? out.close() }
            var remaining = e.size
            while remaining > 0 {
                let toRead = Int(min(remaining, UInt64(chunkSize)))
                let chunk = handle.readData(ofLength: toRead)
                out.write(chunk)
                remaining -= UInt64(chunk.count)
            }
        }
    }
}

// MARK: - Data write helpers

private extension Data {
    mutating func appendUInt16(_ v: UInt16) {
        var be = v.bigEndian; append(Data(bytes: &be, count: 2))
    }
    mutating func appendUInt32(_ v: UInt32) {
        var be = v.bigEndian; append(Data(bytes: &be, count: 4))
    }
    mutating func appendUInt64(_ v: UInt64) {
        var be = v.bigEndian; append(Data(bytes: &be, count: 8))
    }
}

// MARK: - FileHandle read helpers

private extension FileHandle {
    func readBigEndianUInt16() -> UInt16 {
        let d = readData(ofLength: 2)
        return UInt16(bigEndian: d.withUnsafeBytes { $0.load(as: UInt16.self) })
    }
    func readBigEndianUInt32() -> UInt32 {
        let d = readData(ofLength: 4)
        return UInt32(bigEndian: d.withUnsafeBytes { $0.load(as: UInt32.self) })
    }
    func readBigEndianUInt64() -> UInt64 {
        let d = readData(ofLength: 8)
        return UInt64(bigEndian: d.withUnsafeBytes { $0.load(as: UInt64.self) })
    }
}
