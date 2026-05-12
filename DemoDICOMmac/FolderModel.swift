//
//  FolderModel.swift
//  DemoDICOMmac
//

import SwiftUI
internal import Combine

@MainActor
final class FolderModel: ObservableObject {
    @Published var files: [Category: [URL]] = Dictionary(
        uniqueKeysWithValues: Category.allCases.map { ($0, [URL]()) }
    )
    @Published var createdFolderURL: URL?
    @Published var status: String?
    var totalCount: Int { files.values.reduce(0) { $0 + $1.count } }

    func add(_ urls: [URL], to category: Category) {
        var current = files[category] ?? []
        for u in urls where !current.contains(u) { current.append(u) }
        files[category] = current
    }

    func remove(_ url: URL, from category: Category) {
        files[category]?.removeAll { $0 == url }
    }

    func createFolder(named name: String, in parent: URL) {
        let root = parent.appendingPathComponent(name, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            for category in Category.allCases {
                let sub = root.appendingPathComponent(category.rawValue, isDirectory: true)
                try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
                for src in files[category] ?? [] {
                    let dst = sub.appendingPathComponent(src.lastPathComponent)
                    if FileManager.default.fileExists(atPath: dst.path) {
                        try? FileManager.default.removeItem(at: dst)
                    }
                    try FileManager.default.copyItem(at: src, to: dst)
                }
            }
            createdFolderURL = root
            status = "Folder created at \(root.path)"
        } catch {
            status = "Error: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func moveToICloud() -> URL? {
        guard let src = createdFolderURL else { return nil }
        guard let iCloudRoot = iCloudDocumentsURL() else {
            status = "iCloud Drive not available."
            return nil
        }
        do {
            try FileManager.default.createDirectory(at: iCloudRoot, withIntermediateDirectories: true)
            let dst = iCloudRoot.appendingPathComponent(src.lastPathComponent, isDirectory: true)
            if FileManager.default.fileExists(atPath: dst.path) {
                try FileManager.default.removeItem(at: dst)
            }
            try FileManager.default.moveItem(at: src, to: dst)
            createdFolderURL = dst
            status = "Moved to iCloud Drive."
            return dst
        } catch {
            status = "iCloud move failed: \(error.localizedDescription)"
            return nil
        }
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
