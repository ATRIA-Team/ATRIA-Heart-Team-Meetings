//
//  RootView.swift
//  DemoDICOM
//

import SwiftUI
import GroupActivities

/// Routes between `LobbyView` and `ContentView` based on SharePlay session state.
///
/// The `DICOMStore` is owned by `DemoDICOMApp` and injected via `.environment`.
/// This view listens for incoming `GroupSession`s for the lifetime of the window.
struct RootView: View {

    @Environment(DICOMStore.self) private var store

    @Environment(\.openWindow) private var openWindow
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    var body: some View {
        Group {
            if store.sharePlay.isInSession || DebugFlags.bypassSharePlay {
                if store.sharePlay.sessionHasStarted {
                    // Main window becomes the shared window once session is live.
                    NavigationStack { SharedWindow() }
                } else {
                    NavigationStack { LobbyView() }
                }
            } else {
                HomeView2()
            }
        }
        .task {
            // Listen for incoming GroupSessions for the lifetime of this scene.
            for await session in DICOMViewerActivity.sessions() {
                await store.sharePlay.handleIncomingSession(session)
            }
        }
        .onChange(of: store.sharePlay.sessionHasStarted) { _, started in
            if started {
                // Main window transitions to SharedWindow in-place; only the
                // remote-controls companion panel needs to be opened separately.
                openWindow(id: "remoteControls")
            }
        }
        .onChange(of: store.isDrawingActive) { _, newValue in
            // Ensure the immersive drawing space is synced for all participants.
            Task {
                if newValue {
                    store.suppressDrawingToolsPanel = true
                    await openImmersiveSpace(id: "DrawingSpace")
                } else {
                    await dismissImmersiveSpace()
                }
            }
        }
    }
}

