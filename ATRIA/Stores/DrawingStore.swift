//
//  DrawingStore.swift
//  ATRIA
//

import SwiftUI

// MARK: - Notification names

extension Notification.Name {
    /// Posted when a remote draw point arrives from a peer.
    /// `object` is a `DrawPointMessage`.
    static let remoteDrawPoint = Notification.Name("DICOMRemoteDrawPoint")
    /// Posted when any participant (local or remote) clears all drawings.
    static let clearAllDrawings = Notification.Name("DICOMClearAllDrawings")
    /// Posted to undo a stroke (local or remote). `object` is the stroke `UUID`.
    static let undoLastDrawingStroke = Notification.Name("DICOMUndoLastDrawingStroke")
    /// Posted to redo a stroke (local or remote). `object` is the stroke `UUID`.
    static let redoLastDrawingStroke = Notification.Name("DICOMRedoLastDrawingStroke")
}

// MARK: - DrawingStore

/// Owns brush settings, persists stroke data across immersive space sessions,
/// and routes drawing messages to `ImmersiveDrawingView` via `NotificationCenter`.
///
/// Uses `NotificationCenter` because `RealityView` cannot observe `@Observable` state directly.
@Observable
final class DrawingStore {

    // MARK: - Stroke record (persisted across immersive space open/close)

    struct StrokeRecord {
        let id: UUID
        var points: [SIMD3<Float>]
        let thickness: Float
        let color: SIMD4<Float>   // rgba, linear
    }

    /// All strokes currently visible in the scene, keyed by stroke ID.
    /// Persists across immersive space dismissal/reopen so drawings survive stop/start.
    private(set) var activeStrokeData: [UUID: StrokeRecord] = [:]

    /// Strokes that have been undone and are available for redo, keyed by stroke ID.
    private(set) var removedStrokeData: [UUID: StrokeRecord] = [:]

    // MARK: - Observable brush settings (drive the UI)

    var brushColor: Color = .red
    var brushSize: Float = 0.005

    // MARK: - Undo / redo stacks (local strokes only)

    private(set) var undoStack: [UUID] = []
    private(set) var redoStack: [UUID] = []

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    // MARK: - Stroke data recording

    /// Called from `ImmersiveDrawingView.addPoint` for every point (local and remote).
    func recordPoint(strokeID: UUID, point: SIMD3<Float>, thickness: Float, color: SIMD4<Float>) {
        if activeStrokeData[strokeID] == nil {
            activeStrokeData[strokeID] = StrokeRecord(id: strokeID, points: [], thickness: thickness, color: color)
        }
        activeStrokeData[strokeID]?.points.append(point)
    }

    /// Called by `ImmersiveDrawingView` when the stylus button is released and a stroke is complete.
    func strokeCompleted(_ id: UUID) {
        undoStack.append(id)
        redoStack.removeAll()
    }

    // MARK: - Local undo / redo

    @discardableResult
    func undo() -> UUID? {
        guard let id = undoStack.popLast() else { return nil }
        redoStack.append(id)
        moveToRemoved(id: id)
        NotificationCenter.default.post(name: .undoLastDrawingStroke, object: id)
        return id
    }

    @discardableResult
    func redo() -> UUID? {
        guard let id = redoStack.popLast() else { return nil }
        undoStack.append(id)
        moveToActive(id: id)
        NotificationCenter.default.post(name: .redoLastDrawingStroke, object: id)
        return id
    }

    // MARK: - Remote undo / redo (called by SessionStore)

    func remoteUndoStroke(id: UUID) {
        moveToRemoved(id: id)
        NotificationCenter.default.post(name: .undoLastDrawingStroke, object: id)
    }

    func remoteRedoStroke(id: UUID) {
        moveToActive(id: id)
        NotificationCenter.default.post(name: .redoLastDrawingStroke, object: id)
    }

    // MARK: - Routing incoming messages

    func receiveRemotePoint(_ message: DrawPointMessage) {
        NotificationCenter.default.post(name: .remoteDrawPoint, object: message)
    }

    func receiveClearDrawings() {
        undoStack.removeAll()
        redoStack.removeAll()
        activeStrokeData.removeAll()
        removedStrokeData.removeAll()
        NotificationCenter.default.post(name: .clearAllDrawings, object: nil)
    }

    // MARK: - Private helpers

    private func moveToRemoved(id: UUID) {
        if let record = activeStrokeData.removeValue(forKey: id) {
            removedStrokeData[id] = record
        }
    }

    private func moveToActive(id: UUID) {
        if let record = removedStrokeData.removeValue(forKey: id) {
            activeStrokeData[id] = record
        }
    }
}
