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
        let root = parent.appendingPathComponent(packageName, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        var manifestCategories: [String: [String]] = [:]
        for category in Category.allCases {
            let sub = root.appendingPathComponent(category.rawValue, isDirectory: true)
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
        let data = try encoder.encode(manifest)
        try data.write(to: root.appendingPathComponent("manifest.json"))

        return root
    }

    func moveToICloud(_ url: URL) async throws -> URL {
        guard let iCloudRoot = iCloudDocumentsURL() else {
            throw FolderOrganiserError.iCloudNotAvailable
        }
        try FileManager.default.createDirectory(at: iCloudRoot, withIntermediateDirectories: true)
        let destination = iCloudRoot.appendingPathComponent(url.lastPathComponent, isDirectory: true)
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
