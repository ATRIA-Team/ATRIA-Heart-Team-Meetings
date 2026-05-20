//
//  SessionStore.swift
//  DemoDICOM
//

import Foundation
import GroupActivities
import DicomCore

// MARK: - SessionStore

/// Owns the SharePlay session lifecycle and routes incoming messages to domain stores.
/// Breaks the circular `sharePlay.store = self` dependency — the coordinator no longer
/// needs a back-pointer to DICOMStore.
@Observable
final class SessionStore {

    // MARK: - Observable state (forwarded from coordinator)

    var isInSession: Bool           { coordinator.isInSession }
    var sessionHasStarted: Bool     { coordinator.sessionHasStarted }
    var participantStates: [UUID: ParticipantReadyState] { coordinator.participantStates }
    var allParticipantsReady: Bool  { coordinator.allParticipantsReady }
    var participantCount: Int       { coordinator.participantCount }
    var isEligibleForGroupSession: Bool { coordinator.isEligibleForGroupSession }
    var activationError: String? {
        get { coordinator.activationError }
        set { coordinator.activationError = newValue }
    }
    var isApplyingRemoteChange: Bool { coordinator.isApplyingRemoteChange }

    // MARK: - Transport access (for callers that need to send messages)

    let coordinator: SharePlayCoordinator

    // MARK: - Domain store references (for message routing)

    private let viewer:     ViewerStore
    private let annotation: AnnotationStore
    private let document:   DocumentStore
    private let drawing:    DrawingStore

    // MARK: - Drawing space state (session-level concern)

    var isDrawingActive: Bool = false
    var suppressDrawingToolsPanel: Bool = false

    // MARK: - Broadcast helper (set by AppStore to re-broadcast on peer join)

    var onBroadcastAllLoadedExams: (() -> Void)?

    // MARK: - Init

    init(
        coordinator: SharePlayCoordinator,
        viewer:      ViewerStore,
        annotation:  AnnotationStore,
        document:    DocumentStore,
        drawing:     DrawingStore
    ) {
        self.coordinator = coordinator
        self.viewer      = viewer
        self.annotation  = annotation
        self.document    = document
        self.drawing     = drawing

        coordinator.sessionStore = self
    }

    // MARK: - Session API (mirrors SharePlayCoordinator)

    @MainActor
    func activate() async {
        await coordinator.activate()
    }

    @MainActor
    func handleIncomingSession(_ session: GroupSession<DICOMViewerActivity>) async {
        await coordinator.handleIncomingSession(session)
    }

    @MainActor
    func startSession() {
        coordinator.startSession()
    }

    @MainActor
    func leaveSession() {
        coordinator.leaveSession()
    }

    // MARK: - Broadcast helpers (forward to coordinator)

    func send(_ message: DICOMSyncMessage) {
        coordinator.send(message)
    }

    func broadcastExamReady(type: ExamType, metadata: ExamMetadata) {
        coordinator.broadcastExamReady(type: type, metadata: metadata)
    }

    func broadcastExamNotReady(type: ExamType) {
        coordinator.broadcastExamNotReady(type: type)
    }

    func sendDrawPoint(strokeID: UUID, point: SIMD3<Float>, thickness: Float, color: SIMD4<Float>) {
        coordinator.sendDrawPoint(strokeID: strokeID, point: point, thickness: thickness, color: color)
    }

    func sendAnnotation2DPoint(_ message: Annotation2DPointMessage) {
        coordinator.sendAnnotation2DPoint(message)
    }

    func sendClearDrawings() {
        coordinator.sendClearDrawings()
    }

    func sendRemoveAnnotationStrokes(sessionID: UUID, ids: Set<UUID>) {
        coordinator.sendRemoveAnnotationStrokes(sessionID: sessionID, ids: ids)
    }

    // MARK: - Unreliable message routing (called by SharePlayCoordinator)

    @MainActor
    func applyRemoteDrawPoint(_ message: DrawPointMessage) {
        drawing.receiveRemotePoint(message)
    }

    @MainActor
    func applyRemoteAnnotationPoint(_ message: Annotation2DPointMessage) {
        annotation.receiveAnnotationPoint(message)
    }

    // MARK: - Reliable drawing message routing (called by SharePlayCoordinator)

    @MainActor
    func applyRemoteClearDrawings() {
        drawing.receiveClearDrawings()
    }

    @MainActor
    func applyRemoteUndoStroke(id: UUID) {
        drawing.remoteUndoStroke(id: id)
    }

    @MainActor
    func applyRemoteRedoStroke(id: UUID) {
        drawing.remoteRedoStroke(id: id)
    }

    @MainActor
    func applyRemoteRemoveStrokes(sessionID: UUID, strokeIDs: [UUID]) {
        annotation.removeStrokes(sessionID: sessionID, ids: Set(strokeIDs))
    }

    // MARK: - Incoming sync message routing (called by SharePlayCoordinator)

    @MainActor
    func applyMessage(_ message: DICOMSyncMessage) {
        switch message.kind {
        case .sliceChanged(let index):
            viewer.applyRemoteSliceChange(index)

        case .presetChanged(let rawValue):
            guard let preset = MedicalPreset(rawValue: rawValue) else { return }
            viewer.applyRemotePresetChange(preset)

        case .annotationSessionOpened(let sessionID, let sliceIndex):
            annotation.remoteSessionOpened(id: sessionID, sliceIndex: sliceIndex) { [weak self] idx in
                self?.viewer.sliceImages[safe: idx]
            }

        case .annotationSessionClosed(let sessionID):
            annotation.remoteSessionClosed(id: sessionID)

        case .drawingSpaceOpened:
            isDrawingActive = true

        case .drawingSpaceClosed:
            isDrawingActive = false

        case .sharedWindowChanged(let examType):
            document.applySharedWindow(examType)
            if let examType, [ExamType.echo, .ct, .coro].contains(examType) {
                viewer.selectedDICOMExamType = examType
            }

        case .sharedAnnotationChanged(let sessionID):
            document.applySharedAnnotation(sessionID)

        case .pdfScrollChanged(let page, let x, let y, let scaleFactor):
            document.applyRemotePDFState(SharedPDFState(page: page, x: x, y: y, scaleFactor: scaleFactor))

        case .examReady, .examNotReady, .sessionStarted, .clearDrawings,
             .removeAnnotationStrokes, .undoDrawingStroke, .redoDrawingStroke:
            break
        }
    }

    @MainActor
    func notifyNewPeersArrived() {
        onBroadcastAllLoadedExams?()
        for (sessionID, count) in annotation.locallyOpenSessionCount where count > 0 {
            guard let session = annotation.liveSessions[sessionID] else { continue }
            for _ in 0..<count {
                coordinator.send(DICOMSyncMessage(kind: .annotationSessionOpened(
                    sessionID: sessionID,
                    sliceIndex: session.sliceIndex
                )))
            }
        }
    }
}

// MARK: - Array safe subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
