//
//  AnnotationStoreTests.swift
//  DemoDICOMTests
//

import Foundation
import Testing
import CoreGraphics
@testable import ATRIA

// MARK: - AnnotationStoreTests

/// All methods on `AnnotationStore` are `@MainActor`, so the whole suite runs there.
@Suite("AnnotationStore")
@MainActor
struct AnnotationStoreTests {

    // MARK: - Helpers

    private func makeMessage(
        sessionID: UUID,
        strokeID: UUID = UUID(),
        x: Float = 0.5, y: Float = 0.5,
        isStart: Bool = true
    ) -> Annotation2DPointMessage {
        Annotation2DPointMessage(
            sessionID: sessionID, strokeID: strokeID,
            x: x, y: y, isStart: isStart, isEnd: false,
            colorR: 1, colorG: 0, colorB: 0, lineWidth: 2
        )
    }

    // MARK: - createSession

    @Test("createSession adds session to liveSessions")
    func createSessionAddsSession() {
        let store = AnnotationStore()
        let id = UUID()
        store.createSession(id: id, sliceIndex: 2, image: makeCGImage())
        #expect(store.liveSessions[id] != nil)
    }

    @Test("createSession stores the correct sliceIndex")
    func createSessionStoresSliceIndex() {
        let store = AnnotationStore()
        let id = UUID()
        store.createSession(id: id, sliceIndex: 7, image: makeCGImage())
        #expect(store.liveSessions[id]?.sliceIndex == 7)
    }

    @Test("createSession sets locallyOpenSessionCount to 1")
    func createSessionSetsLocalCount() {
        let store = AnnotationStore()
        let id = UUID()
        store.createSession(id: id, sliceIndex: 0, image: makeCGImage())
        #expect(store.locallyOpenSessionCount[id] == 1)
    }

    // MARK: - joinSession

    @Test("joinSession increments open count for an existing session")
    func joinSessionIncrements() {
        let store = AnnotationStore()
        let id = UUID()
        store.createSession(id: id, sliceIndex: 0, image: makeCGImage())
        store.joinSession(id: id)
        #expect(store.locallyOpenSessionCount[id] == 2)
    }

    @Test("joinSession is a no-op for a session that does not exist")
    func joinSessionNoopForNonexistent() {
        let store = AnnotationStore()
        let id = UUID()
        store.joinSession(id: id)
        #expect(store.liveSessions.isEmpty)
        #expect(store.locallyOpenSessionCount.isEmpty)
    }

    // MARK: - closeSession

    @Test("closeSession removes session when the last window closes")
    func closeSessionRemovesAtZero() {
        let store = AnnotationStore()
        let id = UUID()
        store.createSession(id: id, sliceIndex: 0, image: makeCGImage())
        store.closeSession(id: id)
        #expect(store.liveSessions[id] == nil)
        #expect(store.locallyOpenSessionCount[id] == nil)
    }

    @Test("closeSession keeps session alive while other windows are open")
    func closeSessionKeepsWithMultipleWindows() {
        let store = AnnotationStore()
        let id = UUID()
        store.createSession(id: id, sliceIndex: 0, image: makeCGImage())
        store.joinSession(id: id)  // two local windows open
        store.closeSession(id: id)
        #expect(store.liveSessions[id] != nil, "session must remain with one window still open")
        #expect(store.locallyOpenSessionCount[id] == 1)
    }

    @Test("closeSession decrements locallyOpenSessionCount")
    func closeSessionDecrementsLocalCount() {
        let store = AnnotationStore()
        let id = UUID()
        store.createSession(id: id, sliceIndex: 0, image: makeCGImage())
        store.joinSession(id: id)
        store.closeSession(id: id)
        #expect(store.locallyOpenSessionCount[id] == 1)
    }

    // MARK: - isAnnotationPanelVisible

    @Test("isAnnotationPanelVisible is false when there are no sessions")
    func panelNotVisibleWhenEmpty() {
        let store = AnnotationStore()
        #expect(!store.isAnnotationPanelVisible)
    }

    @Test("isAnnotationPanelVisible is true when at least one session exists")
    func panelVisibleWithSession() {
        let store = AnnotationStore()
        store.createSession(id: UUID(), sliceIndex: 0, image: makeCGImage())
        #expect(store.isAnnotationPanelVisible)
    }

    @Test("isAnnotationPanelVisible returns false after all sessions are closed")
    func panelHiddenAfterClose() {
        let store = AnnotationStore()
        let id = UUID()
        store.createSession(id: id, sliceIndex: 0, image: makeCGImage())
        store.closeSession(id: id)
        #expect(!store.isAnnotationPanelVisible)
    }

    // MARK: - remoteSessionOpened

    @Test("remoteSessionOpened creates a new session using the imageProvider")
    func remoteSessionOpenedCreatesSession() {
        let store = AnnotationStore()
        let id = UUID()
        let image = makeCGImage()
        store.remoteSessionOpened(id: id, sliceIndex: 3) { _ in image }
        #expect(store.liveSessions[id] != nil)
        #expect(store.liveSessions[id]?.sliceIndex == 3)
    }

    @Test("remoteSessionOpened increments count if the session already exists")
    func remoteSessionOpenedIncrementsCount() {
        let store = AnnotationStore()
        let id = UUID()
        store.createSession(id: id, sliceIndex: 0, image: makeCGImage())
        store.remoteSessionOpened(id: id, sliceIndex: 0) { _ in makeCGImage() }
        // The session still exists — a second remote peer opened it
        #expect(store.liveSessions[id] != nil)
    }

    @Test("remoteSessionOpened is a no-op when the imageProvider returns nil")
    func remoteSessionOpenedNoopWithNoImage() {
        let store = AnnotationStore()
        let id = UUID()
        store.remoteSessionOpened(id: id, sliceIndex: 99) { _ in nil }
        #expect(store.liveSessions[id] == nil)
    }

    // MARK: - remoteSessionClosed

    @Test("remoteSessionClosed removes session when count reaches zero")
    func remoteSessionClosedRemovesSession() {
        let store = AnnotationStore()
        let id = UUID()
        store.remoteSessionOpened(id: id, sliceIndex: 0) { _ in makeCGImage() }
        store.remoteSessionClosed(id: id)
        #expect(store.liveSessions[id] == nil)
    }

    @Test("remoteSessionClosed keeps session when multiple peers have it open")
    func remoteSessionClosedKeepsWithMultipleOpeners() {
        let store = AnnotationStore()
        let id = UUID()
        store.remoteSessionOpened(id: id, sliceIndex: 0) { _ in makeCGImage() }
        store.remoteSessionOpened(id: id, sliceIndex: 0) { _ in makeCGImage() }
        store.remoteSessionClosed(id: id)
        #expect(store.liveSessions[id] != nil, "one remote opener still active — session must survive")
    }

    // MARK: - receiveAnnotationPoint (stroke management)

    @Test("receiveAnnotationPoint with isStart creates a new stroke")
    func receiveAnnotationPointCreatesStroke() {
        let store = AnnotationStore()
        let sessionID = UUID()
        let strokeID = UUID()
        store.createSession(id: sessionID, sliceIndex: 0, image: makeCGImage())

        let msg = makeMessage(sessionID: sessionID, strokeID: strokeID, isStart: true)
        store.receiveAnnotationPoint(msg)

        #expect(store.liveSessions[sessionID]?.strokes[strokeID] != nil)
        #expect(store.liveSessions[sessionID]?.strokes[strokeID]?.points.count == 1)
    }

    @Test("receiveAnnotationPoint with isStart false appends a point to the existing stroke")
    func receiveAnnotationPointAppendsPoint() {
        let store = AnnotationStore()
        let sessionID = UUID()
        let strokeID = UUID()
        store.createSession(id: sessionID, sliceIndex: 0, image: makeCGImage())

        store.receiveAnnotationPoint(makeMessage(sessionID: sessionID, strokeID: strokeID, x: 0.1, y: 0.1, isStart: true))
        store.receiveAnnotationPoint(makeMessage(sessionID: sessionID, strokeID: strokeID, x: 0.5, y: 0.5, isStart: false))
        store.receiveAnnotationPoint(makeMessage(sessionID: sessionID, strokeID: strokeID, x: 0.9, y: 0.9, isStart: false))

        #expect(store.liveSessions[sessionID]?.strokes[strokeID]?.points.count == 3)
    }

    @Test("receiveAnnotationPoint is a no-op for an unknown session ID")
    func receiveAnnotationPointIgnoresUnknownSession() {
        let store = AnnotationStore()
        let msg = makeMessage(sessionID: UUID())
        store.receiveAnnotationPoint(msg)
        #expect(store.liveSessions.isEmpty)
    }

    // MARK: - removeStrokes

    @Test("removeStrokes removes only the specified stroke IDs")
    func removeStrokesRemovesStrokes() {
        let store = AnnotationStore()
        let sessionID = UUID()
        let id1 = UUID()
        let id2 = UUID()
        store.createSession(id: sessionID, sliceIndex: 0, image: makeCGImage())

        store.receiveAnnotationPoint(makeMessage(sessionID: sessionID, strokeID: id1, isStart: true))
        store.receiveAnnotationPoint(makeMessage(sessionID: sessionID, strokeID: id2, isStart: true))

        store.removeStrokes(sessionID: sessionID, ids: [id1])

        #expect(store.liveSessions[sessionID]?.strokes[id1] == nil)
        #expect(store.liveSessions[sessionID]?.strokes[id2] != nil, "id2 was not in the removal set")
    }

    @Test("removeStrokes is a no-op for an empty ID set")
    func removeStrokesNoopEmptySet() {
        let store = AnnotationStore()
        let sessionID = UUID()
        let strokeID = UUID()
        store.createSession(id: sessionID, sliceIndex: 0, image: makeCGImage())
        store.receiveAnnotationPoint(makeMessage(sessionID: sessionID, strokeID: strokeID, isStart: true))
        store.removeStrokes(sessionID: sessionID, ids: [])
        #expect(store.liveSessions[sessionID]?.strokes[strokeID] != nil)
    }
}
