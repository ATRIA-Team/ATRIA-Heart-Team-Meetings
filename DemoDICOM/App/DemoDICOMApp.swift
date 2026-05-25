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

    @State private var store = AppStore()

    private let annotationContainer: ModelContainer = {
        try! ModelContainer(for: SavedAnnotation.self)
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .task { store.iCloud.start() }
        }
        .defaultSize(width: 1920, height: 1080)
        .modelContainer(annotationContainer)

        WindowGroup(id: "annotation", for: UUID.self) { $sessionID in
            AnnotationView(sessionID: sessionID ?? UUID())
                .environment(store)
        }
        .defaultSize(width: 1080, height: 1080)
        .modelContainer(annotationContainer)

        WindowGroup(id: "drawingTools") {
            DrawingToolsPanel()
                .environment(store)
        }
        .defaultSize(width: 360, height: 220)
        .windowResizability(.contentSize)

        WindowGroup(id: "htmlViewer", for: URL.self) { $url in
            HTMLViewerWindow(url: url)
                .environment(store)
        }
        .defaultSize(width: 800, height: 600)

        WindowGroup(id: "pdfViewer", for: URL.self) { $url in
            PDFViewerWindow(url: url)
                .environment(store)
        }
        .defaultSize(width: 1600, height: 1200)

        WindowGroup(id: "sharedWindow") {
            NavigationStack {
                SharedWindow()
            }
            .environment(store)
        }
        .defaultSize(width: 1200, height: 900)

        WindowGroup(id: "remoteControls") {
            RemoteControlsView()
                .environment(store)
        }
        .defaultSize(width: 760, height: 460)
        .windowResizability(.contentSize)

        ImmersiveSpace(id: "DrawingSpace") {
            ImmersiveDrawingView()
                .environment(store)
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}
