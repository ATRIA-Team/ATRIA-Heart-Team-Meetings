//
//  SharePlayCoordinator.swift
//  ATRIA
//

import GroupActivities
internal import Combine
import Foundation

// MARK: - ParticipantReadyState

/// Tracks the lobby readiness of a single session participant across all exam types.
struct ParticipantReadyState: Identifiable {
    let id: UUID
    let isLocal: Bool

    var loadedExams: Set<ExamType> = []
    var examMetadata: [ExamType: ExamMetadata] = [:]

    var isReady: Bool { !loadedExams.isEmpty }

    // MARK: Convenience accessors for LobbyView

    var sliceCount: Int {
        for examType in [ExamType.ct, .echo, .coro] {
            if case .dicom(let count, _, _) = examMetadata[examType] { return count }
        }
        return 0
    }
    var seriesDescription: String {
        for examType in [ExamType.ct, .echo, .coro] {
            if case .dicom(_, let desc, _) = examMetadata[examType] { return desc }
        }
        return ""
    }
    var patientName: String {
        for examType in [ExamType.ct, .echo, .coro] {
            if case .dicom(_, _, let name) = examMetadata[examType] { return name }
        }
        return ""
    }
}

// MARK: - SharePlayCoordinator

/// Pure transport layer: manages the GroupActivities session lifecycle, sends messages,
/// and forwards received messages to `SessionStore` for routing to domain stores.
/// Has no knowledge of business logic — all routing decisions live in `SessionStore`.
@Observable
final class SharePlayCoordinator: SharePlayTransport {

    // MARK: - Observable state

    private(set) var isInSession: Bool = false
    private(set) var participantStates: [UUID: ParticipantReadyState] = [:]
    private(set) var sessionHasStarted: Bool = false

    var allParticipantsReady: Bool {
        guard !participantStates.isEmpty else { return false }
        return participantStates.values.allSatisfy { $0.isReady }
    }

    var participantCount: Int { participantStates.count }
    private(set) var isEligibleForGroupSession: Bool = false
    var activationError: String?

    // MARK: - Internal

    /// Set by `SessionStore` immediately after it is created.
    weak var sessionStore: SessionStore?

    private(set) var isApplyingRemoteChange: Bool = false

    private var localParticipantID: UUID?
    private var session: GroupSession<DICOMViewerActivity>?
    private var messenger: GroupSessionMessenger?
    private var unreliableMessenger: GroupSessionMessenger?
    private var sessionTasks: [Task<Void, Never>] = []
    private let groupStateObserver = GroupStateObserver()

    // MARK: - Init

    init() {
        let observer = groupStateObserver
        Task { @MainActor [weak self] in
            for await eligible in observer.$isEligibleForGroupSession.values {
                self?.isEligibleForGroupSession = eligible
            }
        }
    }

    // MARK: - Activation

    @MainActor
    func activate() async {
        let activity = DICOMViewerActivity()
        switch await activity.prepareForActivation() {
        case .activationPreferred:
            _ = try? await activity.activate()
        case .activationDisabled:
            activationError = "SharePlay is not available on this device, or it has been disabled in Settings › FaceTime › SharePlay. Note: SharePlay requires a real device and cannot be tested in the simulator."
        case .cancelled:
            break
        @unknown default:
            break
        }
    }

    // MARK: - Session entry

    @MainActor
    func handleIncomingSession(_ session: GroupSession<DICOMViewerActivity>) async {
        sessionTasks.forEach { $0.cancel() }
        sessionTasks = []

        self.session = session
        let messenger = GroupSessionMessenger(session: session)
        self.messenger = messenger
        let unreliableMessenger = GroupSessionMessenger(session: session, deliveryMode: .unreliable)
        self.unreliableMessenger = unreliableMessenger

        let localID = session.localParticipant.id
        localParticipantID = localID

        session.join()

        #if os(visionOS)
        if let coordinator = await session.systemCoordinator {
            var config = SystemCoordinator.Configuration()
            config.supportsGroupImmersiveSpace = true
            coordinator.configuration = config
        }
        #endif

        isInSession = true
        sessionHasStarted = false
        participantStates = [localID: ParticipantReadyState(id: localID, isLocal: true)]

        sessionStore?.notifyNewPeersArrived()

        sessionTasks.append(Task { @MainActor [weak self] in
            guard let self else { return }
            for await participants in session.$activeParticipants.values {
                self.reconcileParticipants(participants, localParticipant: session.localParticipant)
            }
        })

        sessionTasks.append(Task { @MainActor [weak self] in
            guard let self else { return }
            for await state in session.$state.values {
                if case .invalidated = state { self.tearDown(); break }
            }
        })

        sessionTasks.append(Task { @MainActor [weak self] in
            guard let self else { return }
            for await (message, context) in messenger.messages(of: DICOMSyncMessage.self) {
                self.apply(message, from: context.source)
            }
        })

        sessionTasks.append(Task { @MainActor [weak self] in
            guard let self else { return }
            for await (message, _) in unreliableMessenger.messages(of: DrawPointMessage.self) {
                self.sessionStore?.applyRemoteDrawPoint(message)
            }
        })

        sessionTasks.append(Task { @MainActor [weak self] in
            guard let self else { return }
            for await (message, _) in unreliableMessenger.messages(of: Annotation2DPointMessage.self) {
                self.sessionStore?.applyRemoteAnnotationPoint(message)
            }
        })
    }

    // MARK: - Lobby broadcasting

    @MainActor
    func broadcastExamReady(type examType: ExamType, metadata: ExamMetadata) {
        guard isInSession, let localID = localParticipantID else { return }
        var state = participantStates[localID]
        state?.loadedExams.insert(examType)
        state?.examMetadata[examType] = metadata
        participantStates[localID] = state
        send(DICOMSyncMessage(kind: .examReady(type: examType, metadata: metadata)))
    }

    @MainActor
    func startSession() {
        guard (isInSession || DebugFlags.bypassSharePlay),
              (allParticipantsReady || DebugFlags.bypassSharePlay) else { return }
        sessionHasStarted = true
        send(DICOMSyncMessage(kind: .sessionStarted))
    }

    @MainActor
    func broadcastExamNotReady(type examType: ExamType) {
        guard isInSession, let localID = localParticipantID else { return }
        var state = participantStates[localID]
        state?.loadedExams.remove(examType)
        state?.examMetadata.removeValue(forKey: examType)
        participantStates[localID] = state
        send(DICOMSyncMessage(kind: .examNotReady(type: examType)))
    }

    // MARK: - Sending

    func send(_ message: DICOMSyncMessage) {
        guard isInSession, !isApplyingRemoteChange, let messenger else { return }
        Task { try? await messenger.send(message) }
    }

    func sendDrawPoint(strokeID: UUID, point: SIMD3<Float>, thickness: Float, color: SIMD4<Float>) {
        guard isInSession, let unreliableMessenger else { return }
        let message = DrawPointMessage(strokeID: strokeID, point: point, thickness: thickness, color: color)
        Task { try? await unreliableMessenger.send(message) }
    }

    func sendAnnotation2DPoint(_ message: Annotation2DPointMessage) {
        guard isInSession, let unreliableMessenger else { return }
        Task { try? await unreliableMessenger.send(message) }
    }

    func sendClearDrawings() {
        guard isInSession, let messenger else { return }
        Task { try? await messenger.send(DICOMSyncMessage(kind: .clearDrawings)) }
    }

    func sendRemoveAnnotationStrokes(sessionID: UUID, ids: Set<UUID>) {
        guard isInSession, !ids.isEmpty, let messenger else { return }
        Task { try? await messenger.send(DICOMSyncMessage(kind: .removeAnnotationStrokes(sessionID: sessionID, strokeIDs: Array(ids)))) }
    }

    // MARK: - Private

    @MainActor
    private func reconcileParticipants(_ participants: Set<Participant>, localParticipant: Participant) {
        let incomingIDs = Set(participants.map { $0.id })
        let existingIDs = Set(participantStates.keys)

        for id in existingIDs.subtracting(incomingIDs) {
            participantStates.removeValue(forKey: id)
        }

        let newArrivals = incomingIDs.subtracting(existingIDs)
        for participant in participants where newArrivals.contains(participant.id) {
            participantStates[participant.id] = ParticipantReadyState(
                id: participant.id,
                isLocal: participant.id == localParticipant.id
            )
        }

        let newRemoteArrivals = newArrivals.subtracting([localParticipant.id])
        if !newRemoteArrivals.isEmpty {
            sessionStore?.notifyNewPeersArrived()
        }
    }

    @MainActor
    private func apply(_ message: DICOMSyncMessage, from participant: Participant) {
        switch message.kind {

        case .examReady(let examType, let metadata):
            var state = participantStates[participant.id]
            state?.loadedExams.insert(examType)
            state?.examMetadata[examType] = metadata
            participantStates[participant.id] = state

        case .examNotReady(let examType):
            var state = participantStates[participant.id]
            state?.loadedExams.remove(examType)
            state?.examMetadata.removeValue(forKey: examType)
            participantStates[participant.id] = state

        case .sessionStarted:
            sessionHasStarted = true

        case .sliceChanged, .presetChanged, .annotationSessionOpened, .annotationSessionClosed,
             .drawingSpaceOpened, .drawingSpaceClosed, .sharedWindowChanged, .sharedAnnotationChanged, .pdfScrollChanged:
            isApplyingRemoteChange = true
            defer { isApplyingRemoteChange = false }
            sessionStore?.applyMessage(message)

        case .clearDrawings:
            sessionStore?.applyRemoteClearDrawings()

        case .undoDrawingStroke(let strokeID):
            sessionStore?.applyRemoteUndoStroke(id: strokeID)

        case .redoDrawingStroke(let strokeID):
            sessionStore?.applyRemoteRedoStroke(id: strokeID)

        case .removeAnnotationStrokes(let sessionID, let strokeIDs):
            sessionStore?.applyRemoteRemoveStrokes(sessionID: sessionID, strokeIDs: strokeIDs)
        }
    }

    @MainActor
    func leaveSession() {
        session?.leave()
    }

    @MainActor
    func endSessionForEveryone() {
        session?.end()
    }

    @MainActor
    private func tearDown() {
        isInSession = false
        sessionHasStarted = false
        participantStates = [:]
        localParticipantID = nil
        session = nil
        messenger = nil
        unreliableMessenger = nil
        sessionTasks.forEach { $0.cancel() }
        sessionTasks = []
    }
}
