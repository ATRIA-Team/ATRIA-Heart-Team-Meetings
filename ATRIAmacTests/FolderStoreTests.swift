//
//  FolderStoreTests.swift
//  DemoDICOMmacTests
//

import Testing
import Foundation
@testable import DemoDICOMmac

@Suite("FolderStore")
@MainActor
struct FolderStoreTests {

    // MARK: - File collection

    @Test("add stores URLs under the correct category")
    func addFiles() {
        let store = FolderStore(organiser: MockFolderOrganiser())
        let url = URL(fileURLWithPath: "/mock/file.pdf")

        store.add([url], to: .medicalHistory)

        #expect(store.files[.medicalHistory] == [url])
    }

    @Test("add deduplicates URLs")
    func addDeduplicates() {
        let store = FolderStore(organiser: MockFolderOrganiser())
        let url = URL(fileURLWithPath: "/mock/file.pdf")

        store.add([url, url], to: .vitals)

        #expect(store.files[.vitals]?.count == 1)
    }

    @Test("remove deletes the URL from its category")
    func removeFile() {
        let store = FolderStore(organiser: MockFolderOrganiser())
        let url = URL(fileURLWithPath: "/mock/file.pdf")
        store.add([url], to: .bloodTests)

        store.remove(url, from: .bloodTests)

        #expect(store.files[.bloodTests]?.isEmpty == true)
    }

    @Test("totalCount sums files across all categories")
    func totalCount() {
        let store = FolderStore(organiser: MockFolderOrganiser())
        store.add([URL(fileURLWithPath: "/a")], to: .echo)
        store.add([URL(fileURLWithPath: "/b"), URL(fileURLWithPath: "/c")], to: .ct)

        #expect(store.totalCount == 3)
    }

    // MARK: - createFolder

    @Test("createFolder transitions to .ready on success")
    func createFolderSuccess() async {
        let resultURL = URL(fileURLWithPath: "/output/PatientFolder")
        let mock = MockFolderOrganiser(createResult: .success(resultURL))
        let store = FolderStore(organiser: mock)
        let parent = URL(fileURLWithPath: "/output")

        store.createFolder(named: "PatientFolder", in: parent)
        // Yield so the internal Task can complete.
        await Task.yield()
        await Task.yield()

        guard case .ready(let url) = store.folderState else {
            Issue.record("Expected .ready, got \(store.folderState)")
            return
        }
        #expect(url == resultURL)
        #expect(mock.createCallCount == 1)
        #expect(mock.lastCreatedName == "PatientFolder")
        #expect(mock.lastCreatedParent == parent)
    }

    @Test("createFolder transitions to .error on failure")
    func createFolderFailure() async {
        struct FakeError: LocalizedError {
            var errorDescription: String? { "disk full" }
        }
        let mock = MockFolderOrganiser(createResult: .failure(FakeError()))
        let store = FolderStore(organiser: mock)

        store.createFolder(named: "Folder", in: URL(fileURLWithPath: "/tmp"))
        await Task.yield()
        await Task.yield()

        guard case .error(let msg) = store.folderState else {
            Issue.record("Expected .error, got \(store.folderState)")
            return
        }
        #expect(msg == "disk full")
    }

    @Test("createFolder passes a snapshot of files at call time")
    func createFolderPassesSnapshot() async {
        let mock = MockFolderOrganiser()
        let store = FolderStore(organiser: mock)
        let url = URL(fileURLWithPath: "/mock/file.dcm")
        store.add([url], to: .echo)

        store.createFolder(named: "Folder", in: URL(fileURLWithPath: "/tmp"))
        // Mutate after calling — snapshot should not include this.
        store.add([URL(fileURLWithPath: "/mock/extra.dcm")], to: .ct)
        await Task.yield()
        await Task.yield()

        #expect(mock.lastCreatedFiles?[.ct]?.isEmpty == true)
        #expect(mock.lastCreatedFiles?[.echo] == [url])
    }

    // MARK: - moveToICloud

    @Test("moveToICloud is a no-op when state is idle")
    func moveToICloudIdleNoOp() async {
        let mock = MockFolderOrganiser()
        let store = FolderStore(organiser: mock)

        store.moveToICloud()
        await Task.yield()
        await Task.yield()

        #expect(mock.moveCallCount == 0)
    }

    @Test("moveToICloud transitions to new .ready URL on success")
    func moveToICloudSuccess() async {
        let folderURL = URL(fileURLWithPath: "/output/Folder")
        let iCloudURL = URL(fileURLWithPath: "/icloud/Folder")
        let mock = MockFolderOrganiser(moveResult: .success(iCloudURL))
        let store = FolderStore(organiser: mock)
        store.folderState = .ready(folderURL)

        store.moveToICloud()
        await Task.yield()
        await Task.yield()

        guard case .ready(let url) = store.folderState else {
            Issue.record("Expected .ready, got \(store.folderState)")
            return
        }
        #expect(url == iCloudURL)
        #expect(mock.lastMovedURL == folderURL)
    }

    @Test("moveToICloud transitions to .error on failure")
    func moveToICloudFailure() async {
        struct FakeError: LocalizedError {
            var errorDescription: String? { "iCloud not available" }
        }
        let mock = MockFolderOrganiser(moveResult: .failure(FakeError()))
        let store = FolderStore(organiser: mock)
        store.folderState = .ready(URL(fileURLWithPath: "/output/Folder"))

        store.moveToICloud()
        await Task.yield()
        await Task.yield()

        guard case .error(let msg) = store.folderState else {
            Issue.record("Expected .error, got \(store.folderState)")
            return
        }
        #expect(msg == "iCloud not available")
    }

    // MARK: - FolderCreationState helpers

    @Test("folderURL returns nil for idle and error states")
    func folderURLNilForNonReady() {
        #expect(FolderCreationState.idle.folderURL == nil)
        #expect(FolderCreationState.error("oops").folderURL == nil)
    }

    @Test("statusMessage is nil for idle")
    func statusMessageNilForIdle() {
        #expect(FolderCreationState.idle.statusMessage == nil)
    }
}
