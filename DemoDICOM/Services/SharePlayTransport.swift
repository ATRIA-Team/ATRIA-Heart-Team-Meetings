//
//  SharePlayTransport.swift
//  DemoDICOM
//

import Foundation

// MARK: - SharePlayTransport

/// Abstraction over the GroupActivities messenger layer.
/// Conform to this protocol in tests to inject a mock and assert on sent messages
/// without requiring a real GroupSession or FaceTime call.
protocol SharePlayTransport: AnyObject {

    /// True while this device is inside an active GroupSession.
    var isInSession: Bool { get }

    /// Broadcasts a reliable control message to all other participants.
    func send(_ message: DICOMSyncMessage)

    /// Broadcasts an unreliable 3-D draw point to all other participants.
    func sendDrawPoint(strokeID: UUID, point: SIMD3<Float>, thickness: Float, color: SIMD4<Float>)

    /// Broadcasts an unreliable 2-D annotation point to all other participants.
    func sendAnnotation2DPoint(_ message: Annotation2DPointMessage)

    /// Broadcasts a reliable "clear all drawings" message.
    func sendClearDrawings()

    /// Broadcasts a reliable "remove specific annotation strokes" message.
    func sendRemoveAnnotationStrokes(sessionID: UUID, ids: Set<UUID>)
}
