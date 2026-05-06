//
//  DemoDICOMApp.swift
//  DemoDICOM
//
//  Created by Michele Coppola on 25/03/2026.
//

import SwiftUI
import SwiftData
import GroupActivities

@main
struct DemoDICOMApp: App {

    /// Single source of truth — lives for the entire app lifetime.
    @State private var store = DICOMStore()

    /// Single shared container so the main window and the annotation window
    /// read/write the same SwiftData store. Without this, the annotation window
    /// gets an empty default context that does not persist to disk.
    private let annotationContainer: ModelContainer = {
        try! ModelContainer(for: SavedAnnotation.self)
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
        }
        .defaultSize(width: 1920, height: 1080)
        .modelContainer(annotationContainer)

        // 2-D annotation window — one independent window per session UUID.
        // Opened with openWindow(id: "annotation", value: someUUID).
        // visionOS focuses an existing window if the same UUID is requested again,
        // so participants can't accidentally open duplicate windows for one session.
        WindowGroup(id: "annotation", for: UUID.self) { $sessionID in
            AnnotationView(sessionID: sessionID ?? UUID())
                .environment(store)
        }
        .defaultSize(width: 720, height: 780)
        .modelContainer(annotationContainer)  // same instance → same store

        // Floating brush-controls window opened automatically when DrawingSpace opens.
        // Lives as a separate window so the user can drag it anywhere.
        WindowGroup(id: "drawingTools") {
            DrawingToolsPanel()
                .environment(store)
        }
        .defaultSize(width: 360, height: 220)
        .windowResizability(.contentSize)

        // HTML viewer window — opened from ContentView via file picker.
        WindowGroup(id: "htmlViewer") {
            HTMLViewerWindow()
                .environment(store)
        }
        .defaultSize(width: 800, height: 600)

        // PDF viewer window — opened from ContentView via file picker.
        WindowGroup(id: "pdfViewer") {
            PDFViewerWindow()
                .environment(store)
        }
        .defaultSize(width: 1600, height: 1200)

        // Mixed-immersion drawing space.
        // Opened/dismissed from ContentView via openImmersiveSpace / dismissImmersiveSpace.
        ImmersiveSpace(id: "DrawingSpace") {
            ImmersiveDrawingView()
                .environment(store)
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}
