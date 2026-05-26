//
//  MockFolderOrganiser.swift
//  DemoDICOMmacTests
//
//  Test double for FolderOrganising. Returns a pre-configured result without
//  touching the filesystem.
//

import Foundation
@testable import DemoDICOMmac

final class MockFolderOrganiser: FolderOrganising, @unchecked Sendable {

    // MARK: - Configuration

    enum Behaviour {
        case success(URL)
        case failure(Error)
    }

    var createBehaviour: Behaviour
    var moveBehaviour: Behaviour

    init(
        createResult: Behaviour = .success(URL(fileURLWithPath: "/mock/output")),
        moveResult: Behaviour = .success(URL(fileURLWithPath: "/mock/icloud/output"))
    ) {
        self.createBehaviour = createResult
        self.moveBehaviour = moveResult
    }

    // MARK: - Call tracking

    private(set) var createCallCount = 0
    private(set) var lastCreatedName: String?
    private(set) var lastCreatedParent: URL?
    private(set) var lastCreatedFiles: [Category: [URL]]?

    private(set) var moveCallCount = 0
    private(set) var lastMovedURL: URL?

    // MARK: - FolderOrganising

    func createFolder(named name: String, in parent: URL, files: [Category: [URL]]) async throws -> URL {
        createCallCount += 1
        lastCreatedName = name
        lastCreatedParent = parent
        lastCreatedFiles = files
        switch createBehaviour {
        case .success(let url): return url
        case .failure(let error): throw error
        }
    }

    func moveToICloud(_ url: URL) async throws -> URL {
        moveCallCount += 1
        lastMovedURL = url
        switch moveBehaviour {
        case .success(let dst): return dst
        case .failure(let error): throw error
        }
    }
}
