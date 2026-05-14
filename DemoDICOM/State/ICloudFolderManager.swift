//
//  ICloudFolderManager.swift
//  DemoDICOM
//

import Foundation
import ICloudFolderSync

/// Manages a user-selected iCloud Drive folder that mirrors the structure
/// created by the macOS companion app (one subfolder per exam category).
///
/// Call `start()` at app launch to restore any previously selected folder.
/// Call `selectFolder(_:)` when the user picks a new folder.
/// Call `loadAllFiles(into:)` to populate the store from the subfolder structure.
@Observable
@MainActor
final class ICloudFolderManager {

    private let controller = SyncedFolderController()

    /// Display name (last path component) of the currently selected folder, or `nil`.
    private(set) var folderDisplayName: String?

    var hasFolder: Bool { folderDisplayName != nil }

    // Tracks whether we hold an open security-scoped access on the root folder.
    // Kept open so that Task.detached imports inside DICOMStore can reach subfolders.
    private var rootScopeAccessed = false

    // MARK: - Lifecycle

    /// Restores a previously selected folder from the persisted bookmark.
    /// Call once at app launch.
    func start() {
        _ = try? controller.start()
        folderDisplayName = controller.folderDisplayName
        startRootAccess()
    }

    /// Saves and activates a newly chosen folder URL.
    func selectFolder(_ url: URL) throws {
        stopRootAccess()
        try controller.selectFolder(url)
        folderDisplayName = controller.folderDisplayName
        startRootAccess()
    }

    /// Removes the saved folder selection.
    func clearFolder() {
        stopRootAccess()
        controller.clearFolder()
        folderDisplayName = nil
    }

    // MARK: - Loading

    /// Reads every category subfolder in the selected iCloud folder and routes its
    /// contents into `store`, mirroring the structure the macOS companion creates.
    ///
    /// DICOM subfolders (Echo / CT / Coro) → `store.importFolder(url:examType:)`
    /// Document subfolders → the corresponding URL property on the store
    func loadAllFiles(into store: DICOMStore) {
        guard let rootURL = controller.folderURL else { return }

        // Ensure root is accessible for the detached import tasks in DICOMStore.
        if !rootScopeAccessed {
            rootScopeAccessed = rootURL.startAccessingSecurityScopedResource()
        }

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

        let docMappings: [(String, (URL?) -> Void)] = [
            ("Medical History", { store.medicalHistoryURL = $0 }),
            ("Vitals",          { store.vitalsURL         = $0 }),
            ("Blood Tests",     { store.bloodTestURL      = $0 }),
            ("Other",           { store.otherFileURL      = $0 })
        ]
        for (subfolderName, setter) in docMappings {
            let subfolderURL = rootURL.appendingPathComponent(subfolderName)
            setter(firstSupportedFile(in: subfolderURL, using: fm))
        }
    }

    // MARK: - Private

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

    /// Returns the folder that actually contains `.dcm` files for a given category.
    ///
    /// Doctors typically drop an entire scan folder into the companion app, so the
    /// structure is `CT/ → OriginalFolder/ → *.dcm` rather than `CT/ → *.dcm`.
    /// This method checks one level deep and returns whichever folder holds the files.
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

    /// Returns the first PDF or image file found in `folderURL`, sorted by name.
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
