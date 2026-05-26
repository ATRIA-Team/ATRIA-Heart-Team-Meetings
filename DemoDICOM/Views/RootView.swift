//
//  RootView.swift
//  DemoDICOM
//

import SwiftUI
import GroupActivities

/// Routes between `LobbyView` and `SharedWindow` based on SharePlay session state.
struct RootView: View {

    @Environment(AppStore.self) private var store

    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    var body: some View {
        Group {
            if store.session.isInSession || DebugFlags.bypassSharePlay {
                if store.session.sessionHasStarted {
                    NavigationStack { SharedWindow() }
                } else {
                    NavigationStack { LobbyView() }
                }
            } else {
                MainTabView()
            }
        }
        .task {
            for await session in DICOMViewerActivity.sessions() {
                await store.session.handleIncomingSession(session)
            }
        }
        .onChange(of: store.session.sessionHasStarted) { _, started in
            if started { openWindow(id: "remoteControls") }
        }
        .onChange(of: store.isDrawingActive) { _, newValue in
            Task {
                if newValue {
                    store.suppressDrawingToolsPanel = true
                    await openImmersiveSpace(id: "DrawingSpace")
                    openWindow(id: "drawingTools")
                } else {
                    dismissWindow(id: "drawingTools")
                    await dismissImmersiveSpace()
                }
            }
        }
    }
}
