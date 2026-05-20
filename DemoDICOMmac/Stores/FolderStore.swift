//
//  FolderStore.swift
//  DemoDICOMmac
//

import Foundation

// MARK: - FolderCreationState

enum FolderCreationState: Equatable {
    case idle
    case ready(URL)
    case error(String)

    var folderURL: URL? {
        guard case .ready(let url) = self else { return nil }
        return url
    }

    var statusMessage: String? {
        switch self {
        case .idle:               return nil
        case .ready(let url):     return "Folder created at \(url.path)"
        case .error(let message): return message
        }
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):                 return true
        case (.ready(let a), .ready(let b)): return a == b
        case (.error(let a), .error(let b)): return a == b
        default:                             return false
        }
    }
}

// MARK: - FolderStore

@Observable
@MainActor
final class FolderStore {

    var files: [Category: [URL]] = Dictionary(
        uniqueKeysWithValues: Category.allCases.map { ($0, [URL]()) }
    )
    var folderState: FolderCreationState = .idle

    var totalCount: Int { files.values.reduce(0) { $0 + $1.count } }

    private let organiser: any FolderOrganising

    init(organiser: any FolderOrganising = FolderOrganiser()) {
        self.organiser = organiser
    }

    // MARK: - File collection

    func add(_ urls: [URL], to category: Category) {
        var current = files[category] ?? []
        for url in urls where !current.contains(url) { current.append(url) }
        files[category] = current
    }

    func remove(_ url: URL, from category: Category) {
        files[category]?.removeAll { $0 == url }
    }

    // MARK: - Folder actions

    func createFolder(named name: String, in parent: URL) {
        let snapshot = files
        Task {
            do {
                let url = try await organiser.createFolder(named: name, in: parent, files: snapshot)
                folderState = .ready(url)
            } catch {
                folderState = .error(error.localizedDescription)
            }
        }
    }

    func moveToICloud() {
        guard let url = folderState.folderURL else { return }
        Task {
            do {
                let destination = try await organiser.moveToICloud(url)
                folderState = .ready(destination)
            } catch {
                folderState = .error(error.localizedDescription)
            }
        }
    }
}
