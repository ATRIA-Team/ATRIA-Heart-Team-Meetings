//
//  DrawingStoreTests.swift
//  DemoDICOMTests
//

import Foundation
import Testing
@testable import DemoDICOM

// MARK: - DrawingStoreTests

@Suite("DrawingStore")
struct DrawingStoreTests {

    // MARK: - Initial state

    @Test("canUndo and canRedo are false initially")
    func initialState() {
        let store = DrawingStore()
        #expect(!store.canUndo)
        #expect(!store.canRedo)
        #expect(store.activeStrokeData.isEmpty)
        #expect(store.removedStrokeData.isEmpty)
        #expect(store.undoStack.isEmpty)
        #expect(store.redoStack.isEmpty)
    }

    // MARK: - recordPoint

    @Test("recording a point creates a new stroke record")
    func recordPointCreatesStroke() {
        let store = DrawingStore()
        let id = UUID()
        store.recordPoint(strokeID: id, point: .zero, thickness: 0.005, color: .one)
        #expect(store.activeStrokeData[id] != nil)
        #expect(store.activeStrokeData[id]?.points.count == 1)
    }

    @Test("recording multiple points on the same strokeID appends them")
    func recordPointAppendsPoints() {
        let store = DrawingStore()
        let id = UUID()
        store.recordPoint(strokeID: id, point: SIMD3(0, 0, 0), thickness: 0.005, color: .one)
        store.recordPoint(strokeID: id, point: SIMD3(1, 0, 0), thickness: 0.005, color: .one)
        store.recordPoint(strokeID: id, point: SIMD3(2, 0, 0), thickness: 0.005, color: .one)
        #expect(store.activeStrokeData[id]?.points.count == 3)
    }

    @Test("recording points on different strokeIDs creates separate strokes")
    func recordPointSeparateStrokes() {
        let store = DrawingStore()
        let id1 = UUID()
        let id2 = UUID()
        store.recordPoint(strokeID: id1, point: .zero, thickness: 0.005, color: .one)
        store.recordPoint(strokeID: id2, point: .zero, thickness: 0.005, color: .one)
        #expect(store.activeStrokeData.count == 2)
    }

    // MARK: - strokeCompleted

    @Test("strokeCompleted adds the ID to the undoStack")
    func strokeCompletedAddsToUndoStack() {
        let store = DrawingStore()
        let id = UUID()
        store.recordPoint(strokeID: id, point: .zero, thickness: 0.005, color: .one)
        store.strokeCompleted(id)
        #expect(store.undoStack == [id])
        #expect(store.canUndo)
    }

    @Test("strokeCompleted clears the redoStack")
    func strokeCompletedClearsRedoStack() {
        let store = DrawingStore()
        let id1 = UUID()
        let id2 = UUID()

        store.recordPoint(strokeID: id1, point: .zero, thickness: 0.005, color: .one)
        store.strokeCompleted(id1)
        _ = store.undo()
        #expect(store.canRedo)

        store.recordPoint(strokeID: id2, point: .zero, thickness: 0.005, color: .one)
        store.strokeCompleted(id2)
        #expect(!store.canRedo, "completing a new stroke must wipe the redo stack")
    }

    // MARK: - undo

    @Test("undo returns the last completed stroke ID")
    func undoReturnsStrokeID() {
        let store = DrawingStore()
        let id = UUID()
        store.recordPoint(strokeID: id, point: .zero, thickness: 0.005, color: .one)
        store.strokeCompleted(id)
        let returned = store.undo()
        #expect(returned == id)
    }

    @Test("undo moves stroke from active to removed")
    func undoMovesStrokeToRemoved() {
        let store = DrawingStore()
        let id = UUID()
        store.recordPoint(strokeID: id, point: .zero, thickness: 0.005, color: .one)
        store.strokeCompleted(id)
        _ = store.undo()
        #expect(store.activeStrokeData[id] == nil)
        #expect(store.removedStrokeData[id] != nil)
    }

    @Test("undo adds the stroke ID to the redoStack")
    func undoAddsToRedoStack() {
        let store = DrawingStore()
        let id = UUID()
        store.recordPoint(strokeID: id, point: .zero, thickness: 0.005, color: .one)
        store.strokeCompleted(id)
        _ = store.undo()
        #expect(store.redoStack == [id])
        #expect(store.canRedo)
    }

    @Test("undo returns nil when the stack is empty")
    func undoReturnsNilWhenEmpty() {
        let store = DrawingStore()
        #expect(store.undo() == nil)
    }

    @Test("undo posts undoLastDrawingStroke notification with the correct stroke ID")
    func undoPostsNotification() {
        let store = DrawingStore()
        let id = UUID()
        store.recordPoint(strokeID: id, point: .zero, thickness: 0.005, color: .one)
        store.strokeCompleted(id)

        var received: UUID?
        let token = NotificationCenter.default.addObserver(
            forName: .undoLastDrawingStroke, object: nil, queue: nil
        ) { received = $0.object as? UUID }
        defer { NotificationCenter.default.removeObserver(token) }

        _ = store.undo()
        #expect(received == id)
    }

    // MARK: - redo

    @Test("redo returns the last undone stroke ID")
    func redoReturnsStrokeID() {
        let store = DrawingStore()
        let id = UUID()
        store.recordPoint(strokeID: id, point: .zero, thickness: 0.005, color: .one)
        store.strokeCompleted(id)
        _ = store.undo()
        let returned = store.redo()
        #expect(returned == id)
    }

    @Test("redo moves stroke from removed back to active")
    func redoMovesStrokeToActive() {
        let store = DrawingStore()
        let id = UUID()
        store.recordPoint(strokeID: id, point: .zero, thickness: 0.005, color: .one)
        store.strokeCompleted(id)
        _ = store.undo()
        _ = store.redo()
        #expect(store.activeStrokeData[id] != nil)
        #expect(store.removedStrokeData[id] == nil)
    }

    @Test("redo adds the stroke ID back to the undoStack")
    func redoAddsToUndoStack() {
        let store = DrawingStore()
        let id = UUID()
        store.recordPoint(strokeID: id, point: .zero, thickness: 0.005, color: .one)
        store.strokeCompleted(id)
        _ = store.undo()
        _ = store.redo()
        #expect(store.undoStack == [id])
    }

    @Test("redo returns nil when the stack is empty")
    func redoReturnsNilWhenEmpty() {
        let store = DrawingStore()
        #expect(store.redo() == nil)
    }

    @Test("redo posts redoLastDrawingStroke notification with the correct stroke ID")
    func redoPostsNotification() {
        let store = DrawingStore()
        let id = UUID()
        store.recordPoint(strokeID: id, point: .zero, thickness: 0.005, color: .one)
        store.strokeCompleted(id)
        _ = store.undo()

        var received: UUID?
        let token = NotificationCenter.default.addObserver(
            forName: .redoLastDrawingStroke, object: nil, queue: nil
        ) { received = $0.object as? UUID }
        defer { NotificationCenter.default.removeObserver(token) }

        _ = store.redo()
        #expect(received == id)
    }

    // MARK: - Multiple undo / redo cycles

    @Test("multiple undo/redo cycles maintain correct stack order")
    func multipleUndoRedoCycles() {
        let store = DrawingStore()
        let id1 = UUID()
        let id2 = UUID()

        store.recordPoint(strokeID: id1, point: .zero, thickness: 0.005, color: .one)
        store.strokeCompleted(id1)
        store.recordPoint(strokeID: id2, point: .zero, thickness: 0.005, color: .one)
        store.strokeCompleted(id2)

        _ = store.undo() // undoes id2
        _ = store.undo() // undoes id1

        #expect(!store.canUndo)
        #expect(store.canRedo)
        #expect(store.activeStrokeData.isEmpty)

        _ = store.redo() // redoes id1
        #expect(store.activeStrokeData[id1] != nil)
        #expect(store.activeStrokeData[id2] == nil)
    }

    // MARK: - Remote undo / redo

    @Test("remoteUndoStroke moves stroke to removed without touching undo stack")
    func remoteUndoStroke() {
        let store = DrawingStore()
        let id = UUID()
        store.recordPoint(strokeID: id, point: .zero, thickness: 0.005, color: .one)
        // Note: strokeCompleted is NOT called — this is a remote peer's stroke
        store.remoteUndoStroke(id: id)
        #expect(store.activeStrokeData[id] == nil)
        #expect(store.removedStrokeData[id] != nil)
        #expect(store.undoStack.isEmpty, "local undo stack must not be modified by remote actions")
    }

    @Test("remoteRedoStroke moves stroke to active without touching redo stack")
    func remoteRedoStroke() {
        let store = DrawingStore()
        let id = UUID()
        store.recordPoint(strokeID: id, point: .zero, thickness: 0.005, color: .one)
        store.remoteUndoStroke(id: id)
        store.remoteRedoStroke(id: id)
        #expect(store.activeStrokeData[id] != nil)
        #expect(store.removedStrokeData[id] == nil)
        #expect(store.redoStack.isEmpty, "local redo stack must not be modified by remote actions")
    }

    // MARK: - receiveClearDrawings

    @Test("receiveClearDrawings clears all state")
    func receiveClearDrawingsClears() {
        let store = DrawingStore()
        let id = UUID()
        store.recordPoint(strokeID: id, point: .zero, thickness: 0.005, color: .one)
        store.strokeCompleted(id)
        _ = store.undo()
        // Now activeStrokeData is empty but removedStrokeData and stacks are populated
        store.receiveClearDrawings()

        #expect(store.activeStrokeData.isEmpty)
        #expect(store.removedStrokeData.isEmpty)
        #expect(store.undoStack.isEmpty)
        #expect(store.redoStack.isEmpty)
    }

    @Test("receiveClearDrawings posts clearAllDrawings notification")
    func receiveClearDrawingsPostsNotification() {
        let store = DrawingStore()
        var notificationFired = false
        let token = NotificationCenter.default.addObserver(
            forName: .clearAllDrawings, object: nil, queue: nil
        ) { _ in notificationFired = true }
        defer { NotificationCenter.default.removeObserver(token) }

        store.receiveClearDrawings()
        #expect(notificationFired)
    }
}
