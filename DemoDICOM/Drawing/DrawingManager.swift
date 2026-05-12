//
//  DrawingManager.swift
//  DemoDICOM
//

import SwiftUI

// MARK: - Notification names

extension Notification.Name {
    /// Posted when a remote draw point arrives from a peer.
    /// `object` is a `DrawPointMessage`.
    static let remoteDrawPoint = Notification.Name("DICOMRemoteDrawPoint")
    /// Posted when any participant (local or remote) clears all drawings.
    static let clearAllDrawings = Notification.Name("DICOMClearAllDrawings")
    /// Posted to undo the last local stroke. `object` is the stroke `UUID`.
    static let undoLastDrawingStroke = Notification.Name("DICOMUndoLastDrawingStroke")
    /// Posted to redo the last undone local stroke. `object` is the stroke `UUID`.
    static let redoLastDrawingStroke = Notification.Name("DICOMRedoLastDrawingStroke")
}

// MARK: - DrawingManager

/// Owns brush settings and routes incoming drawing messages to the
/// `ImmersiveDrawingView` via `NotificationCenter`.
///
/// Owned by `DICOMStore` so all views can access it through the environment.
@Observable
final class DrawingManager {

    // MARK: - Observable brush settings (drive the UI)

    /// Current brush colour shown in the colour picker.
    var brushColor: Color = .red

    /// Current brush thickness in metres (0.001 … 0.02).
    var brushSize: Float = 0.005

    // MARK: - Undo / redo stacks (local strokes only)

    private(set) var undoStack: [UUID] = []
    private(set) var redoStack: [UUID] = []

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    /// Called by `ImmersiveDrawingView` when the stylus button is released and a stroke is complete.
    func strokeCompleted(_ id: UUID) {
        undoStack.append(id)
        redoStack.removeAll()
    }

    func undo() {
        guard let id = undoStack.popLast() else { return }
        redoStack.append(id)
        NotificationCenter.default.post(name: .undoLastDrawingStroke, object: id)
    }

    func redo() {
        guard let id = redoStack.popLast() else { return }
        undoStack.append(id)
        NotificationCenter.default.post(name: .redoLastDrawingStroke, object: id)
    }

    // MARK: - Routing incoming messages

    /// Called by `SharePlayCoordinator` when a peer sends a draw point.
    /// Routes the message to `ImmersiveDrawingView` via NotificationCenter.
    func receiveRemotePoint(_ message: DrawPointMessage) {
        NotificationCenter.default.post(
            name: .remoteDrawPoint,
            object: message
        )
    }

    /// Called by `SharePlayCoordinator` (or local clear button) to wipe all strokes.
    func receiveClearDrawings() {
        undoStack.removeAll()
        redoStack.removeAll()
        NotificationCenter.default.post(name: .clearAllDrawings, object: nil)
    }
}
