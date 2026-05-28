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
    private static let chunkSize = 4 * 1024 * 1024  // 4 MB chunks

    // MARK: - Read

    /// Extracts the archive at `archiveURL` into `destinationDir`.
    /// Streams file data in 4 MB chunks so large DICOM files don't need to be
    /// fully loaded into memory.
    static func extract(_ archiveURL: URL, to destinationDir: URL) throws {
        let fm = FileManager.default
        let handle = try FileHandle(forReadingFrom: archiveURL)
        defer { try? handle.close() }

        // Verify magic.
        let magicBytes = handle.readData(ofLength: 8)
        guard magicBytes == magic else { throw CocoaError(.fileReadCorruptFile) }

        _ = handle.readBEUInt16()   // version (forward-compat)
        let count = Int(handle.readBEUInt32())

        struct Entry { let path: String; let offset: UInt64; let size: UInt64 }
        var entries: [Entry] = []
        entries.reserveCapacity(count)
        for _ in 0..<count {
            let pathLen = Int(handle.readBEUInt16())
            let pathData = handle.readData(ofLength: pathLen)
            let path = String(bytes: pathData, encoding: .utf8) ?? ""
            let offset = handle.readBEUInt64()
            let size   = handle.readBEUInt64()
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

// MARK: - FileHandle read helpers

private extension FileHandle {
    func readBEUInt16() -> UInt16 {
        let d = readData(ofLength: 2)
        return UInt16(bigEndian: d.withUnsafeBytes { $0.load(as: UInt16.self) })
    }
    func readBEUInt32() -> UInt32 {
        let d = readData(ofLength: 4)
        return UInt32(bigEndian: d.withUnsafeBytes { $0.load(as: UInt32.self) })
    }
    func readBEUInt64() -> UInt64 {
        let d = readData(ofLength: 8)
        return UInt64(bigEndian: d.withUnsafeBytes { $0.load(as: UInt64.self) })
    }
}
