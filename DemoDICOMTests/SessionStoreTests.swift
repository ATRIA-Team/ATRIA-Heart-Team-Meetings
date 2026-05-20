//
//  SessionStoreTests.swift
//  DemoDICOMTests
//
//  Tests for `SessionStore.applyMessage(_:)` — the routing layer between
//  incoming SharePlay messages and domain stores.
//
//  Strategy: instantiate real domain stores and a real (inactive) SharePlayCoordinator.
//  With no live GroupSession, all `coordinator.send(...)` calls are no-ops, so
//  these tests exercise pure routing logic without touching the network.
//

import Foundation
import Testing
import DicomCore
@testable import DemoDICOM

// MARK: - SessionStoreTests

@Suite("SessionStore — applyMessage routing")
@MainActor
struct SessionStoreTests {

    // MARK: - Fixture

    struct TestStores {
        let viewer: ViewerStore
        let annotation: AnnotationStore
        let document: DocumentStore
        let drawing: DrawingStore
        let session: SessionStore
    }

    private func makeStores() -> TestStores {
        let v  = ViewerStore()
        let a  = AnnotationStore()
        let d  = DocumentStore()
        let dr = DrawingStore()
        let coord = SharePlayCoordinator()
        let s = SessionStore(coordinator: coord, viewer: v, annotation: a, document: d, drawing: dr)
        return TestStores(viewer: v, annotation: a, document: d, drawing: dr, session: s)
    }

    // MARK: - Drawing space messages

    @Test("drawingSpaceOpened sets isDrawingActive to true")
    func drawingSpaceOpened() {
        let stores = makeStores()
        stores.session.applyMessage(DICOMSyncMessage(kind: .drawingSpaceOpened))
        #expect(stores.session.isDrawingActive)
    }

    @Test("drawingSpaceClosed sets isDrawingActive to false")
    func drawingSpaceClosed() {
        let stores = makeStores()
        stores.session.applyMessage(DICOMSyncMessage(kind: .drawingSpaceOpened))
        stores.session.applyMessage(DICOMSyncMessage(kind: .drawingSpaceClosed))
        #expect(!stores.session.isDrawingActive)
    }

    // MARK: - Shared window messages

    @Test("sharedWindowChanged routes to DocumentStore")
    func sharedWindowChangedToDocument() {
        let stores = makeStores()
        stores.session.applyMessage(DICOMSyncMessage(kind: .sharedWindowChanged(examType: .medicalHistory)))
        #expect(stores.document.sharedWindowExamType == .medicalHistory)
    }

    @Test("sharedWindowChanged with nil clears the exam type")
    func sharedWindowChangedNilClears() {
        let stores = makeStores()
        stores.session.applyMessage(DICOMSyncMessage(kind: .sharedWindowChanged(examType: .ct)))
        stores.session.applyMessage(DICOMSyncMessage(kind: .sharedWindowChanged(examType: nil)))
        #expect(stores.document.sharedWindowExamType == nil)
    }

    @Test("sharedWindowChanged with a DICOM type also sets ViewerStore.selectedDICOMExamType")
    func sharedWindowChangedDICOMSetsViewer() {
        let stores = makeStores()
        stores.session.applyMessage(DICOMSyncMessage(kind: .sharedWindowChanged(examType: .echo)))
        #expect(stores.viewer.selectedDICOMExamType == .echo)
    }

    @Test("sharedWindowChanged with a document type does not set ViewerStore.selectedDICOMExamType")
    func sharedWindowChangedDocumentDoesNotSetViewer() {
        let stores = makeStores()
        stores.session.applyMessage(DICOMSyncMessage(kind: .sharedWindowChanged(examType: .medicalHistory)))
        #expect(stores.viewer.selectedDICOMExamType == nil)
    }

    @Test("sharedAnnotationChanged routes to DocumentStore")
    func sharedAnnotationChangedToDocument() {
        let stores = makeStores()
        let id = UUID()
        stores.session.applyMessage(DICOMSyncMessage(kind: .sharedAnnotationChanged(sessionID: id)))
        #expect(stores.document.sharedAnnotationSessionID == id)
    }

    @Test("pdfScrollChanged routes to DocumentStore with correct values")
    func pdfScrollChangedToDocument() {
        let stores = makeStores()
        stores.session.applyMessage(DICOMSyncMessage(kind: .pdfScrollChanged(page: 2, x: 10.5, y: 20.5, scaleFactor: 1.5)))
        let state = stores.document.sharedPDFState
        #expect(state?.page == 2)
        #expect(state?.x == 10.5)
        #expect(state?.y == 20.5)
        #expect(state?.scaleFactor == 1.5)
    }

    // MARK: - Viewer messages

    @Test("presetChanged routes to ViewerStore")
    func presetChangedRoutesToViewer() {
        let stores = makeStores()
        stores.session.applyMessage(DICOMSyncMessage(kind: .presetChanged(rawValue: MedicalPreset.bone.rawValue)))
        #expect(stores.viewer.selectedPreset == .bone)
    }

    @Test("presetChanged with an unknown rawValue is ignored")
    func presetChangedUnknownRawValue() {
        let stores = makeStores()
        stores.session.applyMessage(DICOMSyncMessage(kind: .presetChanged(rawValue: 9999)))
        #expect(stores.viewer.selectedPreset == .softTissue, "default preset must not change for unknown rawValue")
    }

    @Test("sliceChanged routes to ViewerStore when a valid exam is loaded")
    func sliceChangedRoutesToViewer() {
        let stores = makeStores()
        stores.viewer.applyImportResult(makeBundle(sliceCount: 5), examType: .ct)
        stores.session.applyMessage(DICOMSyncMessage(kind: .sliceChanged(index: 3)))
        #expect(stores.viewer.currentSliceIndex == 3)
    }

    // MARK: - Annotation messages

    @Test("annotationSessionOpened creates a session in AnnotationStore when viewer has matching slices")
    func annotationSessionOpenedCreatesSession() {
        let stores = makeStores()
        stores.viewer.applyImportResult(makeBundle(sliceCount: 5), examType: .ct)

        let sessionID = UUID()
        stores.session.applyMessage(DICOMSyncMessage(kind: .annotationSessionOpened(sessionID: sessionID, sliceIndex: 2)))

        #expect(stores.annotation.liveSessions[sessionID] != nil)
    }

    @Test("annotationSessionClosed removes an existing session from AnnotationStore")
    func annotationSessionClosedRemovesSession() {
        let stores = makeStores()
        stores.viewer.applyImportResult(makeBundle(sliceCount: 5), examType: .ct)

        let sessionID = UUID()
        stores.session.applyMessage(DICOMSyncMessage(kind: .annotationSessionOpened(sessionID: sessionID, sliceIndex: 1)))
        stores.session.applyMessage(DICOMSyncMessage(kind: .annotationSessionClosed(sessionID: sessionID)))

        #expect(stores.annotation.liveSessions[sessionID] == nil)
    }

    // MARK: - Messages that must not reach domain stores

    @Test("examReady, examNotReady, sessionStarted, clearDrawings, removeAnnotationStrokes, undoDrawingStroke, redoDrawingStroke are handled by coordinator and not re-routed by applyMessage")
    func ignoredKindsDoNotMutateStores() {
        let stores = makeStores()
        let anyUUID = UUID()

        // None of these should throw, panic, or change domain store state
        stores.session.applyMessage(DICOMSyncMessage(kind: .examReady(type: .ct, metadata: .document(fileName: "file"))))
        stores.session.applyMessage(DICOMSyncMessage(kind: .examNotReady(type: .ct)))
        stores.session.applyMessage(DICOMSyncMessage(kind: .sessionStarted))
        stores.session.applyMessage(DICOMSyncMessage(kind: .clearDrawings))
        stores.session.applyMessage(DICOMSyncMessage(kind: .removeAnnotationStrokes(sessionID: anyUUID, strokeIDs: [])))
        stores.session.applyMessage(DICOMSyncMessage(kind: .undoDrawingStroke(strokeID: anyUUID)))
        stores.session.applyMessage(DICOMSyncMessage(kind: .redoDrawingStroke(strokeID: anyUUID)))

        #expect(stores.document.sharedWindowExamType == nil)
        #expect(stores.viewer.selectedDICOMExamType == nil)
        #expect(stores.annotation.liveSessions.isEmpty)
    }
}
