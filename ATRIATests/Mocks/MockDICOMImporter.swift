//
//  MockDICOMImporter.swift
//  DemoDICOMTests
//
//  Test double for `DICOMImporting`. Captures call arguments and returns a
//  pre-configured result (success or failure) without touching the filesystem.
//

import Foundation
import DicomCore
@testable import ATRIA

final class MockDICOMImporter: DICOMImporting {

    // MARK: - Configuration

    enum Behaviour {
        case success(DICOMExamBundle)
        case failure(Error)
    }

    var behaviour: Behaviour

    init(result: Behaviour = .success(makeBundle())) {
        self.behaviour = result
    }

    // MARK: - Call tracking

    private(set) var importCallCount = 0
    private(set) var lastImportedURL: URL?
    private(set) var lastImportedPreset: MedicalPreset?

    // MARK: - DICOMImporting

    func importFolder(url: URL, currentPreset: MedicalPreset) async throws -> DICOMExamBundle {
        importCallCount += 1
        lastImportedURL = url
        lastImportedPreset = currentPreset

        switch behaviour {
        case .success(let bundle): return bundle
        case .failure(let error):  throw error
        }
    }
}
