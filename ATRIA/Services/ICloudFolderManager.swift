//
//  ICloudFolderManager.swift
//  ATRIA
//

import Foundation
import ICloudFolderSync

/// Manages the user-selected iCloud Drive source for exam files.
///
/// Supports two source types:
/// - A plain iCloud folder created before the .atria format (legacy).
/// - An `.atria` package created by the macOS companion app.
///
/// Call `start()` at app launch to restore any previously selected source.
@Observable
@MainActor
final class ICloudFolderManager {

    private let controller = SyncedFolderController()

    private(set) var folderDisplayName: String?
    var hasFolder: Bool { folderDisplayName != nil }

    // Security-scoped access for the plain iCloud folder.
    private var rootScopeAccessed = false

    // Security-scoped access and bookmark for .atria files.
    private var atriaURL: URL?
    private var atriaAccessed = false
    private static let atriaBookmarkKey = "atriaPackageBookmark"

    // Local extraction directory (inside the app's caches folder).
    private var extractedAtriaDir: URL?

    // MARK: - Lifecycle

    func start() {
        _ = try? controller.start()
        if let name = controller.folderDisplayName {
            folderDisplayName = name
            startRootAccess()
        } else {
            restoreAtriaBookmark()
        }
    }

    func selectFolder(_ url: URL) throws {
        stopAtriaAccess()
        clearAtriaBookmark()
        stopRootAccess()
        try controller.selectFolder(url)
        folderDisplayName = controller.folderDisplayName
        startRootAccess()
    }

    /// Opens an `.atria` file, extracts it to the app's caches directory, persists
    /// a security-scoped bookmark, and loads all exam files into `store`.
    func openAtriaPackage(_ url: URL, into store: AppStore) {
        stopRootAccess()
        controller.clearFolder()
        stopAtriaAccess()
        saveAtriaBookmark(url)
        atriaURL = url
        atriaAccessed = url.startAccessingSecurityScopedResource()
        folderDisplayName = url.deletingPathExtension().lastPathComponent

        do {
            let extracted = try extractedDirectory(for: url)
            extractedAtriaDir = extracted
            loadFiles(from: extracted, into: store)
        } catch {
            // Extraction failed — nothing to load.
        }
    }

    private func extractedDirectory(for archiveURL: URL) throws -> URL {
        let name = archiveURL.deletingPathExtension().lastPathComponent
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dest = caches.appendingPathComponent("atria_extracted/\(name)", isDirectory: true)
        // Re-extract every time to pick up changes from iCloud sync.
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try AtriaArchive.extract(archiveURL, to: dest)
        return dest
    }

    func clearFolder() {
        stopRootAccess()
        controller.clearFolder()
        stopAtriaAccess()
        clearAtriaBookmark()
        if let dir = extractedAtriaDir {
            try? FileManager.default.removeItem(at: dir)
            extractedAtriaDir = nil
        }
        folderDisplayName = nil
    }

    // MARK: - Loading

    func loadAllFiles(into store: AppStore) {
        if let extracted = extractedAtriaDir {
            loadFiles(from: extracted, into: store)
            return
        }
        guard let rootURL = controller.folderURL else { return }
        if !rootScopeAccessed {
            rootScopeAccessed = rootURL.startAccessingSecurityScopedResource()
        }
        loadFiles(from: rootURL, into: store)
    }

    // MARK: - Private: loading

    private func loadFiles(from rootURL: URL, into store: AppStore) {
        let fm = FileManager.default

        let dicomMappings: [(String, ExamType)] = [
            ("Echo", .echo),
            ("CT",   .ct),
            ("Coro", .coro)
        ]
        for (subfolderName, examType) in dicomMappings {
            let categoryURL = rootURL.appendingPathComponent(subfolderName)
            guard fm.fileExists(atPath: categoryURL.path) else { continue }
            if let dicomURL = resolvedDICOMFolder(under: categoryURL, using: fm) {
                store.importFolder(url: dicomURL, examType: examType)
            }
        }

        let docMappings: [(String, (URL) -> Void)] = [
            ("Medical History", { store.addMedicalHistory($0) }),
            ("Vitals",          { store.addVitals($0) }),
            ("Blood Tests",     { store.addBloodTests($0) }),
            ("Other",           { store.addOther($0) })
        ]
        for (subfolderName, add) in docMappings {
            let subfolderURL = rootURL.appendingPathComponent(subfolderName)
            if let url = firstSupportedFile(in: subfolderURL, using: fm) { add(url) }
        }
    }

    // MARK: - Private: security-scoped access

    private func startRootAccess() {
        guard !rootScopeAccessed, let url = controller.folderURL else { return }
        rootScopeAccessed = url.startAccessingSecurityScopedResource()
    }

    private func stopRootAccess() {
        guard rootScopeAccessed, let url = controller.folderURL else {
            rootScopeAccessed = false
            return
        }
        url.stopAccessingSecurityScopedResource()
        rootScopeAccessed = false
    }

    private func stopAtriaAccess() {
        guard atriaAccessed, let url = atriaURL else {
            atriaAccessed = false
            atriaURL = nil
            return
        }
        url.stopAccessingSecurityScopedResource()
        atriaAccessed = false
        atriaURL = nil
    }

    // MARK: - Private: .atria bookmark persistence

    private func saveAtriaBookmark(_ url: URL) {
        let data = try? url.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        UserDefaults.standard.set(data, forKey: Self.atriaBookmarkKey)
    }

    private func restoreAtriaBookmark() {
        guard let data = UserDefaults.standard.data(forKey: Self.atriaBookmarkKey) else { return }
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ), !isStale else {
            clearAtriaBookmark()
            return
        }
        atriaURL = url
        atriaAccessed = url.startAccessingSecurityScopedResource()
        folderDisplayName = url.deletingPathExtension().lastPathComponent
        extractedAtriaDir = try? extractedDirectory(for: url)
    }

    private func clearAtriaBookmark() {
        UserDefaults.standard.removeObject(forKey: Self.atriaBookmarkKey)
    }

    // MARK: - Private: folder scanning helpers

    private func resolvedDICOMFolder(under categoryURL: URL, using fm: FileManager) -> URL? {
        if containsDICOMFiles(at: categoryURL, using: fm) {
            return categoryURL
        }
        guard let contents = try? fm.contentsOfDirectory(
            at: categoryURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }
        return contents
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .min(by: { $0.lastPathComponent < $1.lastPathComponent })
    }

    private func containsDICOMFiles(at url: URL, using fm: FileManager) -> Bool {
        guard let contents = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return false }
        let dicomExtensions: Set<String> = ["dcm", "dicom", "ima"]
        return contents.contains {
            let isReg = (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
            let ext = $0.pathExtension.lowercased()
            return isReg && (dicomExtensions.contains(ext) || ext.isEmpty)
        }
    }

    private func firstSupportedFile(in folderURL: URL, using fm: FileManager) -> URL? {
        guard let contents = try? fm.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        let supported: Set<String> = ["pdf", "jpg", "jpeg", "png", "heic"]
        return contents
            .filter {
                (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
                    && supported.contains($0.pathExtension.lowercased())
            }
            .min(by: { $0.lastPathComponent < $1.lastPathComponent })
    }
}
