//
//  FolderOrganiser.swift
//  DemoDICOMmac
//

import Foundation

enum FolderOrganiserError: LocalizedError {
    case iCloudNotAvailable

    var errorDescription: String? {
        switch self {
        case .iCloudNotAvailable: return "iCloud Drive is not available on this device."
        }
    }
}

actor FolderOrganiser: FolderOrganising {

    func createFolder(named name: String, in parent: URL, files: [Category: [URL]]) async throws -> URL {
        let packageName = name.hasSuffix(".atria") ? name : "\(name).atria"
        let destination = parent.appendingPathComponent(packageName)

        // Build directory structure in a temp folder, then archive it.
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)

        var manifestCategories: [String: [String]] = [:]
        for category in Category.allCases {
            let sub = tempRoot.appendingPathComponent(category.rawValue, isDirectory: true)
            try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
            var filenames: [String] = []
            for src in files[category] ?? [] {
                let dst = sub.appendingPathComponent(src.lastPathComponent)
                if FileManager.default.fileExists(atPath: dst.path) {
                    try? FileManager.default.removeItem(at: dst)
                }
                try FileManager.default.copyItem(at: src, to: dst)
                filenames.append(src.lastPathComponent)
            }
            manifestCategories[category.rawValue] = filenames
        }

        let manifest = AtriaManifest(
            patientName: name,
            createdAt: Date(),
            categories: manifestCategories
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let manifestData = try encoder.encode(manifest)
        try manifestData.write(to: tempRoot.appendingPathComponent("manifest.json"))

        try AtriaArchive.write(from: tempRoot, to: destination)
        return destination
    }

    func moveToICloud(_ url: URL) async throws -> URL {
        guard let iCloudRoot = iCloudDocumentsURL() else {
            throw FolderOrganiserError.iCloudNotAvailable
        }
        try FileManager.default.createDirectory(at: iCloudRoot, withIntermediateDirectories: true)
        let destination = iCloudRoot.appendingPathComponent(url.lastPathComponent)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: url, to: destination)
        return destination
    }

    private func iCloudDocumentsURL() -> URL? {
        if let container = FileManager.default.url(forUbiquityContainerIdentifier: nil) {
            return container.appendingPathComponent("Documents")
        }
        let path = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
        return FileManager.default.fileExists(atPath: path.path) ? path : nil
    }
}
