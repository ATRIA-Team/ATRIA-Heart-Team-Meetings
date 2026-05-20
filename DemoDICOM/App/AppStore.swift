//
//  AppStore.swift
//  DemoDICOM
//

import SwiftUI
import CoreGraphics
import DicomCore
import UniformTypeIdentifiers

// MARK: - AppStore

/// The single source of truth injected into the SwiftUI environment.
/// Composes domain stores and provides cross-cutting action methods.
/// Views access domain state via `store.viewer`, `store.session`, etc.
@Observable
final class AppStore {

    // MARK: - Domain stores

    let viewer:     ViewerStore
    let annotation: AnnotationStore
    let document:   DocumentStore
    var drawing:    DrawingStore
    let session:    SessionStore

    // MARK: - Services

    let iCloud: ICloudFolderManager
    private let importer: any DICOMImporting

    // MARK: - Init

    init(importer: any DICOMImporting = DICOMImporter()) {
        let coordinator = SharePlayCoordinator()
        let v  = ViewerStore()
        let a  = AnnotationStore()
        let d  = DocumentStore()
        let dr = DrawingStore()
        let ic = ICloudFolderManager()
        let s  = SessionStore(coordinator: coordinator, viewer: v, annotation: a, document: d, drawing: dr)

        self.viewer     = v
        self.annotation = a
        self.document   = d
        self.drawing    = dr
        self.session    = s
        self.iCloud     = ic
        self.importer   = importer

        s.onBroadcastAllLoadedExams = { [weak self] in
            self?.broadcastAllLoadedExams()
        }
    }

    // MARK: - Cross-cutting drawing actions

    /// Clears all 3-D drawings locally and broadcasts to peers.
    func clearAllDrawings() {
        drawing.receiveClearDrawings()
        session.sendClearDrawings()
    }

    func undo3DStroke() {
        if let id = drawing.undo() {
            session.send(DICOMSyncMessage(kind: .undoDrawingStroke(strokeID: id)))
        }
    }

    func redo3DStroke() {
        if let id = drawing.redo() {
            session.send(DICOMSyncMessage(kind: .redoDrawingStroke(strokeID: id)))
        }
    }

    // MARK: - Cross-cutting annotation actions

    /// Applies a 2-D annotation point locally and broadcasts it to peers.
    @MainActor
    func sendAnnotationPoint(_ msg: Annotation2DPointMessage) {
        annotation.receiveAnnotationPoint(msg)
        session.sendAnnotation2DPoint(msg)
    }

    @MainActor
    func createAnnotationSession(id: UUID, sliceIndex: Int, image: CGImage) {
        annotation.createSession(id: id, sliceIndex: sliceIndex, image: image)
        session.send(DICOMSyncMessage(kind: .annotationSessionOpened(sessionID: id, sliceIndex: sliceIndex)))
    }

    @MainActor
    func joinAnnotationSession(id: UUID) {
        guard let s = annotation.liveSessions[id] else { return }
        annotation.joinSession(id: id)
        session.send(DICOMSyncMessage(kind: .annotationSessionOpened(sessionID: id, sliceIndex: s.sliceIndex)))
    }

    @MainActor
    func closeAnnotationSession(id: UUID) {
        annotation.closeSession(id: id)
        session.send(DICOMSyncMessage(kind: .annotationSessionClosed(sessionID: id)))
    }

    @MainActor
    func removeAnnotationStrokes(sessionID: UUID, ids: Set<UUID>) {
        annotation.removeStrokes(sessionID: sessionID, ids: ids)
        session.sendRemoveAnnotationStrokes(sessionID: sessionID, ids: ids)
    }

    // MARK: - Slice navigation (broadcasts on change)

    var currentSliceIndex: Int {
        get { viewer.currentSliceIndex }
        set {
            guard newValue != viewer.currentSliceIndex else { return }
            viewer.currentSliceIndex = newValue
            session.send(DICOMSyncMessage(kind: .sliceChanged(index: newValue)))
        }
    }

    // MARK: - Preset (broadcasts + re-applies windowing)

    var selectedPreset: MedicalPreset {
        get { viewer.selectedPreset }
        set {
            guard newValue != viewer.selectedPreset else { return }
            viewer.selectedPreset = newValue
            session.send(DICOMSyncMessage(kind: .presetChanged(rawValue: newValue.rawValue)))
            viewer.reapplyWindowing { [weak self] images, examType in
                self?.viewer.applyRewindowedImages(images, examType: examType)
            }
        }
    }

    // MARK: - Drawing space state (broadcasts on change)

    var isDrawingActive: Bool {
        get { session.isDrawingActive }
        set {
            guard newValue != session.isDrawingActive else { return }
            session.isDrawingActive = newValue
            session.send(DICOMSyncMessage(kind: newValue ? .drawingSpaceOpened : .drawingSpaceClosed))
        }
    }

    var suppressDrawingToolsPanel: Bool {
        get { session.suppressDrawingToolsPanel }
        set { session.suppressDrawingToolsPanel = newValue }
    }

    // MARK: - Shared window actions (broadcasts on change)

    func pushToSharedWindow(_ examType: ExamType?) {
        guard examType != document.sharedWindowExamType else { return }
        document.applySharedWindow(examType)
        if let examType, [ExamType.echo, .ct, .coro].contains(examType) {
            viewer.selectedDICOMExamType = examType
        }
        session.send(DICOMSyncMessage(kind: .sharedWindowChanged(examType: examType)))
    }

    func setSharedAnnotation(_ sessionID: UUID?) {
        guard sessionID != document.sharedAnnotationSessionID else { return }
        document.applySharedAnnotation(sessionID)
        session.send(DICOMSyncMessage(kind: .sharedAnnotationChanged(sessionID: sessionID)))
    }

    func setLocalPDFState(_ state: SharedPDFState?) {
        guard state != document.sharedPDFState else { return }
        document.setLocalPDFState(state)
        if let state {
            session.send(DICOMSyncMessage(kind: .pdfScrollChanged(
                page: state.page, x: state.x, y: state.y, scaleFactor: state.scaleFactor
            )))
        }
    }

    // MARK: - Document URL actions (append; broadcasts the newly added file)

    func addMedicalHistory(_ url: URL) {
        document.addMedicalHistory(url)
        broadcastDocumentChange(.medicalHistory, url: url)
    }

    func removeMedicalHistory(_ url: URL) {
        document.removeMedicalHistory(url)
        if document.medicalHistoryURLs.isEmpty { session.broadcastExamNotReady(type: .medicalHistory) }
    }

    func addVitals(_ url: URL) {
        document.addVitals(url)
        broadcastDocumentChange(.vitals, url: url)
    }

    func removeVitals(_ url: URL) {
        document.removeVitals(url)
        if document.vitalsURLs.isEmpty { session.broadcastExamNotReady(type: .vitals) }
    }

    func addBloodTests(_ url: URL) {
        document.addBloodTests(url)
        broadcastDocumentChange(.bloodTests, url: url)
    }

    func removeBloodTests(_ url: URL) {
        document.removeBloodTests(url)
        if document.bloodTestURLs.isEmpty { session.broadcastExamNotReady(type: .bloodTests) }
    }

    func addOther(_ url: URL) {
        document.addOther(url)
        broadcastDocumentChange(.other, url: url)
    }

    func removeOther(_ url: URL) {
        document.removeOther(url)
        if document.otherFileURLs.isEmpty { session.broadcastExamNotReady(type: .other) }
    }

    // MARK: - DICOM import

    @MainActor
    func removeExam(_ examType: ExamType) {
        viewer.removeExam(examType)
        session.broadcastExamNotReady(type: examType)
    }

    @MainActor
    func removeBundle(id: UUID, examType: ExamType) {
        viewer.removeBundle(id: id, examType: examType)
        if viewer.dicomExams[examType] == nil {
            session.broadcastExamNotReady(type: examType)
        }
    }

    @MainActor
    func importFolder(url: URL, examType: ExamType = .ct) {
        viewer.prepareForImport(examType: examType)
        session.broadcastExamNotReady(type: examType)

        Task.detached { [weak self] in
            guard let self else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            do {
                let preset = await MainActor.run { self.viewer.selectedPreset }
                let bundle = try await self.importer.importFolder(url: url, currentPreset: preset)
                await MainActor.run {
                    self.viewer.applyImportResult(bundle, examType: examType)
                    self.session.broadcastExamReady(
                        type: examType,
                        metadata: .dicom(
                            sliceCount: bundle.sliceCount,
                            seriesDescription: bundle.seriesDescription,
                            patientName: bundle.patientName
                        )
                    )
                }
            } catch {
                await MainActor.run { self.viewer.applyImportError(error.localizedDescription) }
            }
        }
    }

    // MARK: - Broadcasting

    func broadcastDocumentChange(_ examType: ExamType, url: URL?) {
        if let url {
            session.broadcastExamReady(type: examType, metadata: .document(fileName: url.deletingPathExtension().lastPathComponent))
        } else {
            session.broadcastExamNotReady(type: examType)
        }
    }

    @MainActor
    func broadcastAllLoadedExams() {
        for (examType, bundles) in viewer.dicomExams {
            let idx = viewer.selectedBundleIndices[examType] ?? 0
            let bundle = idx < bundles.count ? bundles[idx] : bundles[0]
            if !bundle.sliceImages.isEmpty {
                session.broadcastExamReady(
                    type: examType,
                    metadata: .dicom(sliceCount: bundle.sliceCount, seriesDescription: bundle.seriesDescription, patientName: bundle.patientName)
                )
            }
        }
        if let url = document.medicalHistoryURLs.first { broadcastDocumentChange(.medicalHistory, url: url) }
        if let url = document.vitalsURLs.first         { broadcastDocumentChange(.vitals,         url: url) }
        if let url = document.bloodTestURLs.first      { broadcastDocumentChange(.bloodTests,     url: url) }
        if let url = document.otherFileURLs.first      { broadcastDocumentChange(.other,          url: url) }
    }
}
