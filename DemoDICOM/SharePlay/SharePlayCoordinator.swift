//
//  SharePlayCoordinator.swift
//  DemoDICOM
//

import GroupActivities
internal import Combine
import Foundation

// MARK: - ParticipantReadyState

/// Tracks the lobby readiness of a single session participant across all exam types.
struct ParticipantReadyState: Identifiable {
    let id: UUID
    let isLocal: Bool

    /// Which exam types this participant has finished loading.
    var loadedExams: Set<ExamType> = []

    /// Lightweight metadata per loaded exam, used by the lobby UI.
    var examMetadata: [ExamType: ExamMetadata] = [:]

    /// Derived: participant is fully ready when every required exam type is loaded.
    var isReady: Bool { loadedExams == ExamType.allRequired }

    // MARK: Convenience accessors for LobbyView

    var sliceCount: Int {
        if case .dicom(let count, _, _) = examMetadata[.dicom] { return count }
        return 0
    }
    var seriesDescription: String {
        if case .dicom(_, let desc, _) = examMetadata[.dicom] { return desc }
        return ""
    }
    var patientName: String {
        if case .dicom(_, _, let name) = examMetadata[.dicom] { return name }
        return ""
    }
}

// MARK: - SharePlayCoordinator

/// Manages the full SharePlay session lifecycle:
///
/// **Lobby phase** — tracks per-participant, per-exam-type readiness via `participantStates`.
/// Once every participant has loaded every required exam type, `sessionHasStarted` latches
/// to `true` and `RootView` transitions to the viewer. Late-joining participants do not push
/// active viewers back to the lobby.
///
/// **Viewer phase** — syncs `currentSliceIndex` and `selectedPreset` in real time
/// via `send(_:)`, guarded by `isApplyingRemoteChange` to prevent echo loops.
@Observable
final class SharePlayCoordinator {

    // MARK: - Observable state

    /// True while this device is inside an active GroupSession.
    private(set) var isInSession: Bool = false

    /// Per-participant lobby state, keyed by `Participant.ID` (UUID).
    private(set) var participantStates: [UUID: ParticipantReadyState] = [:]

    /// True once every participant has reported ready. Stays true for the
    /// remainder of the session so late joiners don't interrupt the viewer.
    private(set) var sessionHasStarted: Bool = false

    /// True when all known participants have loaded all required exam types.
    var allParticipantsReady: Bool {
        guard !participantStates.isEmpty else { return false }
        return participantStates.values.allSatisfy { $0.isReady }
    }

    /// Number of participants currently in the session (including this device).
    var participantCount: Int { participantStates.count }

    /// True when the device is in an active FaceTime call and SharePlay is
    /// available. When false, the system sheet will offer to start a call first.
    private(set) var isEligibleForGroupSession: Bool = false

    /// Set when activation fails (e.g. SharePlay disabled in Settings).
    /// Views should present this as an alert and then clear it.
    var activationError: String?

    // MARK: - Internal

    /// Back-reference to the store; set immediately after `DICOMStore.init()`.
    weak var store: DICOMStore?

    /// Raised while applying a received slice/preset message so that
    /// `DICOMStore`'s `didSet` observers don't re-broadcast the change.
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

    /// Presents the system SharePlay / FaceTime invitation sheet.
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

    /// Called by `RootView` each time a `GroupSession` arrives.
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

        // If the store already has data loaded before SharePlay started,
        // immediately broadcast readiness for each exam type already loaded.
        if let store {
            if store.sliceCount > 0 {
                broadcastExamReady(
                    type: .dicom,
                    metadata: .dicom(
                        sliceCount: store.sliceCount,
                        seriesDescription: store.seriesDescription,
                        patientName: store.patientName
                    )
                )
            }
            if let fileName = store.bloodTestFileName {
                broadcastExamReady(type: .bloodTests, metadata: .bloodTests(fileName: fileName))
            }
            if let fileName = store.medicalRecordFileName {
                broadcastExamReady(type: .medicalRecord, metadata: .medicalRecord(fileName: fileName))
            }
        }

        sessionTasks.append(Task { @MainActor [weak self] in
            guard let self else { return }
            for await participants in session.$activeParticipants.values {
                self.reconcileParticipants(participants, localParticipant: session.localParticipant)
            }
        })

        sessionTasks.append(Task { @MainActor [weak self] in
            guard let self else { return }
            for await state in session.$state.values {
                if case .invalidated = state {
                    self.tearDown()
                    break
                }
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
                self.store?.drawing.receiveRemotePoint(message)
            }
        })

        sessionTasks.append(Task { @MainActor [weak self] in
            guard let self else { return }
            for await (message, _) in unreliableMessenger.messages(of: Annotation2DPointMessage.self) {
                self.store?.receiveAnnotation2DPoint(message)
            }
        })
    }

    // MARK: - Lobby broadcasting

    /// Marks one exam type as ready for the local participant and notifies all peers.
    @MainActor
    func broadcastExamReady(type examType: ExamType, metadata: ExamMetadata) {
        guard isInSession, let localID = localParticipantID else { return }
        participantStates[localID]?.loadedExams.insert(examType)
        participantStates[localID]?.examMetadata[examType] = metadata
        checkSessionStart()
        send(DICOMSyncMessage(kind: .examReady(type: examType, metadata: metadata)))
    }

    /// Marks one exam type as not-ready for the local participant and notifies all peers.
    @MainActor
    func broadcastExamNotReady(type examType: ExamType) {
        guard isInSession, let localID = localParticipantID else { return }
        participantStates[localID]?.loadedExams.remove(examType)
        participantStates[localID]?.examMetadata.removeValue(forKey: examType)
        send(DICOMSyncMessage(kind: .examNotReady(type: examType)))
    }

    // MARK: - Viewer state sending

    /// Broadcasts a slice/preset message to all other participants.
    func send(_ message: DICOMSyncMessage) {
        guard isInSession, !isApplyingRemoteChange, let messenger else { return }
        Task {
            try? await messenger.send(message)
        }
    }

    func sendDrawPoint(strokeID: UUID, point: SIMD3<Float>, thickness: Float, color: SIMD4<Float>) {
        guard isInSession, let unreliableMessenger else { return }
        let message = DrawPointMessage(strokeID: strokeID, point: point, thickness: thickness, color: color)
        Task {
            try? await unreliableMessenger.send(message)
        }
    }

    func sendAnnotation2DPoint(_ message: Annotation2DPointMessage) {
        guard isInSession, let unreliableMessenger else { return }
        Task {
            try? await unreliableMessenger.send(message)
        }
    }

    func sendClearDrawings() {
        guard isInSession, let messenger else { return }
        Task {
            try? await messenger.send(DICOMSyncMessage(kind: .clearDrawings))
        }
    }

    func sendRemoveAnnotationStrokes(sessionID: UUID, ids: Set<UUID>) {
        guard isInSession, !ids.isEmpty, let messenger else { return }
        Task {
            try? await messenger.send(DICOMSyncMessage(kind: .removeAnnotationStrokes(sessionID: sessionID, strokeIDs: Array(ids))))
        }
    }

    // MARK: - Private

    @MainActor
    private func reconcileParticipants(
        _ participants: Set<Participant>,
        localParticipant: Participant
    ) {
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

        // Re-broadcast every exam type already loaded so late joiners learn our state.
        let newRemoteArrivals = newArrivals.subtracting([localParticipant.id])
        if !newRemoteArrivals.isEmpty, let localState = participantStates[localParticipant.id] {
            for examType in localState.loadedExams {
                if let metadata = localState.examMetadata[examType] {
                    broadcastExamReady(type: examType, metadata: metadata)
                }
            }

            // Re-broadcast every annotation session this device currently has open.
            if let store {
                for (sessionID, count) in store.locallyOpenSessionCount where count > 0 {
                    guard let session = store.liveSessions[sessionID] else { continue }
                    for _ in 0..<count {
                        send(DICOMSyncMessage(kind: .annotationSessionOpened(
                            sessionID: sessionID,
                            sliceIndex: session.sliceIndex
                        )))
                    }
                }
            }
        }
    }

    @MainActor
    private func apply(_ message: DICOMSyncMessage, from participant: Participant) {
        switch message.kind {

        case .examReady(let examType, let metadata):
            participantStates[participant.id]?.loadedExams.insert(examType)
            participantStates[participant.id]?.examMetadata[examType] = metadata
            checkSessionStart()

        case .examNotReady(let examType):
            participantStates[participant.id]?.loadedExams.remove(examType)
            participantStates[participant.id]?.examMetadata.removeValue(forKey: examType)

        case .sliceChanged, .presetChanged, .annotationSessionOpened, .annotationSessionClosed, .drawingSpaceOpened, .drawingSpaceClosed:
            isApplyingRemoteChange = true
            defer { isApplyingRemoteChange = false }
            store?.applySharePlayMessage(message)

        case .clearDrawings:
            store?.drawing.receiveClearDrawings()

        case .removeAnnotationStrokes(let sessionID, let strokeIDs):
            store?.removeAnnotationStrokes(sessionID: sessionID, ids: Set(strokeIDs))
        }
    }

    @MainActor
    private func checkSessionStart() {
        if !sessionHasStarted && allParticipantsReady {
            sessionHasStarted = true
        }
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
