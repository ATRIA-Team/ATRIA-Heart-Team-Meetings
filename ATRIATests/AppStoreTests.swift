//
//  AppStoreTests.swift
//  DemoDICOMTests
//
//  Tests for the cross-cutting coordination logic in AppStore — the methods that
//  mutate multiple domain stores at once and broadcast to peers.
//
//  Strategy: construct a real AppStore with a MockDICOMImporter so that
//  coordinator.send() calls are no-ops (no live GroupSession). Each test
//  verifies that the correct domain-store state changes after an AppStore action.
//

import Testing
import Foundation
@testable import ATRIA
import DicomCore

@Suite("AppStore — cross-cutting actions")
@MainActor
struct AppStoreTests {

    private func makeStore() -> AppStore {
        AppStore(importer: MockDICOMImporter())
    }

    // MARK: - Document URL actions

    @Test("addMedicalHistory is forwarded to DocumentStore")
    func addMedicalHistoryForwards() {
        let store = makeStore()
        let url = URL(fileURLWithPath: "/tmp/history.pdf")
        store.addMedicalHistory(url)
        #expect(store.document.medicalHistoryURLs.contains(url))
    }

    @Test("removeMedicalHistory is forwarded to DocumentStore")
    func removeMedicalHistoryForwards() {
        let store = makeStore()
        let url = URL(fileURLWithPath: "/tmp/history.pdf")
        store.addMedicalHistory(url)
        store.removeMedicalHistory(url)
        #expect(store.document.medicalHistoryURLs.isEmpty)
    }

    @Test("addVitals is forwarded to DocumentStore")
    func addVitalsForwards() {
        let store = makeStore()
        let url = URL(fileURLWithPath: "/tmp/vitals.pdf")
        store.addVitals(url)
        #expect(store.document.vitalsURLs.contains(url))
    }

    @Test("removeVitals is forwarded to DocumentStore")
    func removeVitalsForwards() {
        let store = makeStore()
        let url = URL(fileURLWithPath: "/tmp/vitals.pdf")
        store.addVitals(url)
        store.removeVitals(url)
        #expect(store.document.vitalsURLs.isEmpty)
    }

    @Test("addBloodTests is forwarded to DocumentStore")
    func addBloodTestsForwards() {
        let store = makeStore()
        let url = URL(fileURLWithPath: "/tmp/blood.pdf")
        store.addBloodTests(url)
        #expect(store.document.bloodTestURLs.contains(url))
    }

    @Test("removeBloodTests is forwarded to DocumentStore")
    func removeBloodTestsForwards() {
        let store = makeStore()
        let url = URL(fileURLWithPath: "/tmp/blood.pdf")
        store.addBloodTests(url)
        store.removeBloodTests(url)
        #expect(store.document.bloodTestURLs.isEmpty)
    }

    @Test("addOther is forwarded to DocumentStore")
    func addOtherForwards() {
        let store = makeStore()
        let url = URL(fileURLWithPath: "/tmp/file.pdf")
        store.addOther(url)
        #expect(store.document.otherFileURLs.contains(url))
    }

    @Test("removeOther is forwarded to DocumentStore")
    func removeOtherForwards() {
        let store = makeStore()
        let url = URL(fileURLWithPath: "/tmp/file.pdf")
        store.addOther(url)
        store.removeOther(url)
        #expect(store.document.otherFileURLs.isEmpty)
    }

    // MARK: - pushToSharedWindow

    @Test("pushToSharedWindow sets sharedWindowExamType on DocumentStore")
    func pushToSharedWindowSetsExamType() {
        let store = makeStore()
        store.pushToSharedWindow(.ct)
        #expect(store.document.sharedWindowExamType == .ct)
    }

    @Test("pushToSharedWindow with a DICOM type also sets ViewerStore.selectedDICOMExamType")
    func pushToSharedWindowDICOMAlsoSetsViewer() {
        let store = makeStore()
        store.pushToSharedWindow(.echo)
        #expect(store.viewer.selectedDICOMExamType == .echo)
    }

    @Test("pushToSharedWindow with a document type does not set ViewerStore.selectedDICOMExamType")
    func pushToSharedWindowDocumentDoesNotSetViewer() {
        let store = makeStore()
        store.pushToSharedWindow(.medicalHistory)
        #expect(store.viewer.selectedDICOMExamType == nil)
    }

    @Test("pushToSharedWindow with nil clears the shared exam type and any PDF state")
    func pushToSharedWindowNilClears() {
        let store = makeStore()
        store.pushToSharedWindow(.ct)
        store.pushToSharedWindow(nil)
        #expect(store.document.sharedWindowExamType == nil)
        #expect(store.document.sharedPDFState == nil)
    }

    @Test("pushToSharedWindow is idempotent for the same exam type")
    func pushToSharedWindowIdempotent() {
        let store = makeStore()
        store.pushToSharedWindow(.coro)
        store.pushToSharedWindow(.coro)
        #expect(store.document.sharedWindowExamType == .coro)
    }

    // MARK: - setSharedAnnotation

    @Test("setSharedAnnotation sets sharedAnnotationSessionID on DocumentStore")
    func setSharedAnnotationSetsID() {
        let store = makeStore()
        let id = UUID()
        store.setSharedAnnotation(id)
        #expect(store.document.sharedAnnotationSessionID == id)
    }

    @Test("setSharedAnnotation with nil clears the session ID")
    func setSharedAnnotationNilClears() {
        let store = makeStore()
        store.setSharedAnnotation(UUID())
        store.setSharedAnnotation(nil)
        #expect(store.document.sharedAnnotationSessionID == nil)
    }

    // MARK: - currentSliceIndex

    @Test("currentSliceIndex setter updates ViewerStore when a bundle is loaded")
    func currentSliceIndexSetterUpdatesViewer() {
        let store = makeStore()
        store.viewer.applyImportResult(makeBundle(sliceCount: 5), examType: .ct)
        store.currentSliceIndex = 3
        #expect(store.viewer.currentSliceIndex == 3)
    }

    @Test("currentSliceIndex setter is a no-op when the value is already current")
    func currentSliceIndexSetterNoopForSameValue() {
        let store = makeStore()
        store.viewer.applyImportResult(makeBundle(sliceCount: 5), examType: .ct)
        store.currentSliceIndex = 2
        store.currentSliceIndex = 2
        #expect(store.viewer.currentSliceIndex == 2)
    }

    // MARK: - selectedPreset

    @Test("selectedPreset setter updates ViewerStore.selectedPreset")
    func selectedPresetSetterUpdatesViewer() {
        let store = makeStore()
        #expect(store.viewer.selectedPreset == .softTissue)
        store.selectedPreset = .bone
        #expect(store.viewer.selectedPreset == .bone)
    }

    @Test("selectedPreset setter is a no-op when the value is already set")
    func selectedPresetSetterNoopForSameValue() {
        let store = makeStore()
        store.selectedPreset = .softTissue
        #expect(store.viewer.selectedPreset == .softTissue)
    }

    // MARK: - Drawing actions

    @Test("clearAllDrawings clears all DrawingStore state")
    func clearAllDrawingsClears() {
        let store = makeStore()
        let id = UUID()
        store.drawing.recordPoint(strokeID: id, point: .zero, thickness: 0.005, color: .one)
        store.drawing.strokeCompleted(id)
        store.clearAllDrawings()
        #expect(store.drawing.activeStrokeData.isEmpty)
        #expect(store.drawing.removedStrokeData.isEmpty)
        #expect(store.drawing.undoStack.isEmpty)
        #expect(!store.drawing.canUndo)
    }

    @Test("undo3DStroke moves the last completed stroke from active to removed")
    func undo3DStrokeMovesToRemoved() {
        let store = makeStore()
        let id = UUID()
        store.drawing.recordPoint(strokeID: id, point: .zero, thickness: 0.005, color: .one)
        store.drawing.strokeCompleted(id)
        store.undo3DStroke()
        #expect(store.drawing.activeStrokeData[id] == nil)
        #expect(store.drawing.removedStrokeData[id] != nil)
    }

    @Test("undo3DStroke is a no-op when the undo stack is empty")
    func undo3DStrokeNoopWhenEmpty() {
        let store = makeStore()
        store.undo3DStroke()
        #expect(store.drawing.activeStrokeData.isEmpty)
        #expect(store.drawing.removedStrokeData.isEmpty)
    }

    @Test("redo3DStroke moves the last undone stroke back to active")
    func redo3DStrokeMovesToActive() {
        let store = makeStore()
        let id = UUID()
        store.drawing.recordPoint(strokeID: id, point: .zero, thickness: 0.005, color: .one)
        store.drawing.strokeCompleted(id)
        store.undo3DStroke()
        store.redo3DStroke()
        #expect(store.drawing.activeStrokeData[id] != nil)
        #expect(store.drawing.removedStrokeData[id] == nil)
    }

    @Test("redo3DStroke is a no-op when the redo stack is empty")
    func redo3DStrokeNoopWhenEmpty() {
        let store = makeStore()
        store.redo3DStroke()
        #expect(store.drawing.activeStrokeData.isEmpty)
        #expect(store.drawing.removedStrokeData.isEmpty)
    }

    // MARK: - DICOM remove actions

    @Test("removeExam forwards to ViewerStore and clears the selection")
    func removeExamForwards() {
        let store = makeStore()
        store.viewer.applyImportResult(makeBundle(), examType: .ct)
        store.removeExam(.ct)
        #expect(store.viewer.dicomExams[.ct] == nil)
        #expect(store.viewer.selectedDICOMExamType == nil)
    }

    @Test("removeExam for a non-selected exam does not clear selectedDICOMExamType")
    func removeExamKeepsOtherSelection() {
        let store = makeStore()
        store.viewer.applyImportResult(makeBundle(), examType: .echo)
        store.viewer.applyImportResult(makeBundle(), examType: .ct)
        store.removeExam(.echo)
        #expect(store.viewer.selectedDICOMExamType == .ct)
    }

    @Test("removeBundle removes only the targeted bundle")
    func removeBundleTargeted() {
        let store = makeStore()
        let first  = makeBundle(sliceCount: 3)
        let second = makeBundle(sliceCount: 5)
        store.viewer.applyImportResult(first,  examType: .ct)
        store.viewer.applyImportResult(second, examType: .ct)
        store.removeBundle(id: first.id, examType: .ct)
        #expect(store.viewer.dicomExams[.ct]?.count == 1)
        #expect(store.viewer.dicomExams[.ct]?.first?.id == second.id)
    }

    @Test("removeBundle clears the exam type when the last bundle is removed")
    func removeBundleClearsExamTypeWhenLast() {
        let store = makeStore()
        let bundle = makeBundle()
        store.viewer.applyImportResult(bundle, examType: .echo)
        store.removeBundle(id: bundle.id, examType: .echo)
        #expect(store.viewer.dicomExams[.echo] == nil)
        #expect(store.viewer.selectedDICOMExamType == nil)
    }
}
