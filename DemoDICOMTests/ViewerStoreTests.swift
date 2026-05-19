//
//  ViewerStoreTests.swift
//  DemoDICOMTests
//

import Testing
import CoreGraphics
import DicomCore
@testable import DemoDICOM

// MARK: - ViewerStoreTests

@Suite("ViewerStore")
struct ViewerStoreTests {

    // MARK: - Initial state

    @Test("initial state is empty with no loading or errors")
    func initialState() {
        let store = ViewerStore()
        #expect(store.dicomExams.isEmpty)
        #expect(store.selectedDICOMExamType == nil)
        #expect(store.loadedDICOMExamTypes.isEmpty)
        #expect(!store.isLoading)
        #expect(store.errorMessage == nil)
    }

    @Test("sliceImages returns empty when no exam is selected")
    func sliceImagesEmptyWithNoExam() {
        let store = ViewerStore()
        #expect(store.sliceImages.isEmpty)
    }

    @Test("currentSliceIndex defaults to 0 when no exam is selected")
    func currentSliceIndexDefault() {
        let store = ViewerStore()
        #expect(store.currentSliceIndex == 0)
    }

    // MARK: - prepareForImport

    @Test("prepareForImport sets isLoading to true")
    func prepareForImportSetsLoading() {
        let store = ViewerStore()
        store.prepareForImport(examType: .ct)
        #expect(store.isLoading)
    }

    @Test("prepareForImport clears any existing errorMessage")
    func prepareForImportClearsError() {
        let store = ViewerStore()
        store.applyImportError("previous error")
        store.prepareForImport(examType: .ct)
        #expect(store.errorMessage == nil)
    }

    @Test("prepareForImport sets selectedDICOMExamType")
    func prepareForImportSetsExamType() {
        let store = ViewerStore()
        store.prepareForImport(examType: .echo)
        #expect(store.selectedDICOMExamType == .echo)
    }

    // MARK: - applyImportResult

    @Test("applyImportResult stores the bundle and clears loading")
    func applyImportResult() {
        let store = ViewerStore()
        let bundle = makeBundle(sliceCount: 5)
        store.applyImportResult(bundle, examType: .ct)
        #expect(store.dicomExams[.ct] != nil)
        #expect(!store.isLoading)
    }

    @Test("applyImportResult selects the imported exam type")
    func applyImportResultSelectsExamType() {
        let store = ViewerStore()
        store.applyImportResult(makeBundle(), examType: .echo)
        #expect(store.selectedDICOMExamType == .echo)
    }

    @Test("sliceImages returns the bundle slices after a successful import")
    func sliceImagesAfterImport() {
        let store = ViewerStore()
        let bundle = makeBundle(sliceCount: 3)
        store.applyImportResult(bundle, examType: .ct)
        #expect(store.sliceImages.count == 3)
    }

    // MARK: - applyImportError

    @Test("applyImportError sets errorMessage and clears loading")
    func applyImportError() {
        let store = ViewerStore()
        store.prepareForImport(examType: .ct)
        store.applyImportError("Something went wrong")
        #expect(store.errorMessage == "Something went wrong")
        #expect(!store.isLoading)
    }

    // MARK: - removeExam

    @Test("removeExam removes the bundle for that exam type")
    func removeExam() {
        let store = ViewerStore()
        store.applyImportResult(makeBundle(), examType: .ct)
        store.removeExam(.ct)
        #expect(store.dicomExams[.ct] == nil)
    }

    @Test("removeExam clears selectedDICOMExamType when the removed exam was selected")
    func removeExamClearsSelectionIfSelected() {
        let store = ViewerStore()
        store.applyImportResult(makeBundle(), examType: .ct)
        store.removeExam(.ct)
        #expect(store.selectedDICOMExamType == nil)
    }

    @Test("removeExam keeps selectedDICOMExamType when a different exam is removed")
    func removeExamKeepsSelectionIfDifferent() {
        let store = ViewerStore()
        store.applyImportResult(makeBundle(), examType: .echo)
        store.applyImportResult(makeBundle(), examType: .ct)  // CT is now selected
        store.removeExam(.echo)                               // remove a different exam
        #expect(store.selectedDICOMExamType == .ct)
    }

    // MARK: - loadedDICOMExamTypes

    @Test("loadedDICOMExamTypes includes only DICOM exam types with non-empty slices")
    func loadedDICOMExamTypesFiltering() {
        let store = ViewerStore()
        store.applyImportResult(makeBundle(sliceCount: 3), examType: .ct)
        store.applyImportResult(makeBundle(sliceCount: 2), examType: .echo)
        // .medicalHistory should never appear in loadedDICOMExamTypes
        store.applyImportResult(makeBundle(sliceCount: 1), examType: .medicalHistory)

        let loaded = store.loadedDICOMExamTypes
        #expect(loaded.contains(.ct))
        #expect(loaded.contains(.echo))
        #expect(!loaded.contains(.medicalHistory))
    }

    @Test("loadedDICOMExamTypes is empty after removing all exams")
    func loadedDICOMExamTypesEmptyAfterRemoval() {
        let store = ViewerStore()
        store.applyImportResult(makeBundle(), examType: .ct)
        store.removeExam(.ct)
        #expect(store.loadedDICOMExamTypes.isEmpty)
    }

    // MARK: - applyRemoteSliceChange

    @Test("applyRemoteSliceChange updates currentSliceIndex")
    func applyRemoteSliceChange() {
        let store = ViewerStore()
        store.applyImportResult(makeBundle(sliceCount: 5), examType: .ct)
        store.applyRemoteSliceChange(3)
        #expect(store.currentSliceIndex == 3)
    }

    @Test("applyRemoteSliceChange ignores an out-of-bounds index")
    func applyRemoteSliceChangeOutOfBounds() {
        let store = ViewerStore()
        store.applyImportResult(makeBundle(sliceCount: 3), examType: .ct)
        store.applyRemoteSliceChange(10)
        #expect(store.currentSliceIndex == 0, "index 10 is out of bounds for a 3-slice exam")
    }

    @Test("applyRemoteSliceChange is a no-op when no exam is selected")
    func applyRemoteSliceChangeNoExam() {
        let store = ViewerStore()
        store.applyRemoteSliceChange(5)
        #expect(store.currentSliceIndex == 0)
    }

    // MARK: - applyRemotePresetChange

    @Test("applyRemotePresetChange updates selectedPreset")
    func applyRemotePresetChange() {
        let store = ViewerStore()
        #expect(store.selectedPreset == .softTissue)
        store.applyRemotePresetChange(.bone)
        #expect(store.selectedPreset == .bone)
    }

    // MARK: - applyRewindowedImages

    @Test("applyRewindowedImages replaces sliceImages for the given exam type")
    func applyRewindowedImages() {
        let store = ViewerStore()
        store.applyImportResult(makeBundle(sliceCount: 2), examType: .ct)

        let newImages = [makeCGImage(), makeCGImage(), makeCGImage()]
        store.applyRewindowedImages(newImages, examType: .ct)

        #expect(store.sliceImages.count == 3)
        #expect(!store.isLoading)
    }

    @Test("applyRewindowedImages clamps currentSliceIndex when the new count is smaller")
    func applyRewindowedImagesClampsIndex() {
        let store = ViewerStore()
        store.applyImportResult(makeBundle(sliceCount: 5), examType: .ct)
        store.currentSliceIndex = 4

        store.applyRewindowedImages([makeCGImage()], examType: .ct)
        #expect(store.currentSliceIndex == 0)
    }

    // MARK: - Metadata passthrough

    @Test("patientName returns bundle value after import")
    func patientNamePassthrough() {
        let store = ViewerStore()
        store.applyImportResult(makeBundle(patientName: "Jane Doe"), examType: .ct)
        #expect(store.patientName == "Jane Doe")
    }

    @Test("seriesDescription returns bundle value after import")
    func seriesDescriptionPassthrough() {
        let store = ViewerStore()
        store.applyImportResult(makeBundle(seriesDescription: "Chest CT"), examType: .ct)
        #expect(store.seriesDescription == "Chest CT")
    }
}
