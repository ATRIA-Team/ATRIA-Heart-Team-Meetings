//
//  AnnotationStore.swift
//  DemoDICOM
//

import SwiftUI
import CoreGraphics

// MARK: - AnnotationPanelStroke

struct AnnotationPanelStroke {
    let id: UUID
    var points: [CGPoint]
    let color: Color
    let lineWidth: CGFloat
}

// MARK: - LiveAnnotationSession

struct LiveAnnotationSession: Identifiable {
    let id: UUID
    let sliceIndex: Int
    let frozenImage: CGImage
    var strokes: [UUID: AnnotationPanelStroke] = [:]
}

// MARK: - AnnotationStore

/// Owns all live 2-D annotation sessions and their strokes.
/// Session lifecycle is symmetric: local open/join/close and remote counterparts.
@Observable
final class AnnotationStore {

    // MARK: - State

    private(set) var liveSessions: [UUID: LiveAnnotationSession] = [:]

    /// Total open-window count per session across all participants (local + remote).
    private var sessionOpenCounts: [UUID: Int] = [:]

    /// How many windows *this device* has open per session.
    /// Re-broadcast to late joiners so they learn our open sessions.
    private(set) var locallyOpenSessionCount: [UUID: Int] = [:]

    var isAnnotationPanelVisible: Bool { !liveSessions.isEmpty }

    // MARK: - Local session lifecycle

    @MainActor
    func createSession(id: UUID, sliceIndex: Int, image: CGImage) {
        liveSessions[id] = LiveAnnotationSession(id: id, sliceIndex: sliceIndex, frozenImage: image)
        sessionOpenCounts[id] = 1
        locallyOpenSessionCount[id, default: 0] += 1
    }

    @MainActor
    func joinSession(id: UUID) {
        guard liveSessions[id] != nil else { return }
        sessionOpenCounts[id, default: 0] += 1
        locallyOpenSessionCount[id, default: 0] += 1
    }

    @MainActor
    func closeSession(id: UUID) {
        locallyOpenSessionCount[id, default: 0] = max(0, (locallyOpenSessionCount[id] ?? 0) - 1)
        if locallyOpenSessionCount[id] == 0 { locallyOpenSessionCount.removeValue(forKey: id) }

        let newCount = max(0, (sessionOpenCounts[id] ?? 0) - 1)
        sessionOpenCounts[id] = newCount
        if newCount == 0 {
            liveSessions.removeValue(forKey: id)
            sessionOpenCounts.removeValue(forKey: id)
        }
    }

    // MARK: - Remote session lifecycle

    @MainActor
    func remoteSessionOpened(id: UUID, sliceIndex: Int, imageProvider: (Int) -> CGImage?) {
        if liveSessions[id] != nil {
            sessionOpenCounts[id, default: 0] += 1
        } else {
            guard let image = imageProvider(sliceIndex) else { return }
            liveSessions[id] = LiveAnnotationSession(id: id, sliceIndex: sliceIndex, frozenImage: image)
            sessionOpenCounts[id] = 1
        }
    }

    @MainActor
    func remoteSessionClosed(id: UUID) {
        let newCount = max(0, (sessionOpenCounts[id] ?? 0) - 1)
        sessionOpenCounts[id] = newCount
        if newCount == 0 {
            liveSessions.removeValue(forKey: id)
            sessionOpenCounts.removeValue(forKey: id)
        }
    }

    // MARK: - Stroke management

    @MainActor
    func receiveAnnotationPoint(_ msg: Annotation2DPointMessage) {
        guard liveSessions[msg.sessionID] != nil else { return }
        let pt = CGPoint(x: CGFloat(msg.x), y: CGFloat(msg.y))
        let color = Color(red: Double(msg.colorR), green: Double(msg.colorG), blue: Double(msg.colorB))
        if msg.isStart {
            liveSessions[msg.sessionID]?.strokes[msg.strokeID] = AnnotationPanelStroke(
                id: msg.strokeID, points: [pt], color: color, lineWidth: CGFloat(msg.lineWidth)
            )
        } else {
            liveSessions[msg.sessionID]?.strokes[msg.strokeID]?.points.append(pt)
        }
    }

    @MainActor
    func removeStrokes(sessionID: UUID, ids: Set<UUID>) {
        for id in ids { liveSessions[sessionID]?.strokes.removeValue(forKey: id) }
    }
}
