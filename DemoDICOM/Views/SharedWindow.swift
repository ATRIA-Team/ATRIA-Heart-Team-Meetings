//
//  SharedWindow.swift
//  DemoDICOM
//
//  Created by Igor Tarantino on 07/05/2026.
//

import SwiftUI
import PDFKit

struct SharedWindow: View {

    @Environment(AppStore.self) private var store
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    // Local drawing state for the shared annotation canvas
    @State private var canvasState    = PencilCanvasState()
    @State private var brushColor: Color   = .red
    @State private var brushSize:  CGFloat = 3.0
    @State private var localStrokeIDs: Set<UUID> = []

    var body: some View {
        Group {
            if let sessionID = store.document.sharedAnnotationSessionID,
               let session = store.annotation.liveSessions[sessionID] {
                annotationViewer(session: session)
            } else if let examType = store.document.sharedWindowExamType {
                sharedContent(for: examType)
            } else {
                placeholderView
            }
        }
        .navigationTitle(sharedWindowTitle)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    dismissWindow(id: "remoteControls")
                    store.session.leaveSession()
                } label: {
                    HStack {
                        Image(systemName: "shareplay.slash")
                        Text("End SharePlay session")
                    }
                    .foregroundStyle(Color.red)
                }
            }
        }
        .background {
            WindowInteractionToggle(enabled: !store.isDrawingActive)
        }
    }

    // MARK: - Navigation title

    private var sharedWindowTitle: String {
        if let sessionID = store.document.sharedAnnotationSessionID,
           let session = store.annotation.liveSessions[sessionID] {
            return "Annotation — Slice \(session.sliceIndex + 1)"
        }
        return store.document.sharedWindowExamType?.displayName ?? "Shared Window"
    }

    // MARK: - Annotation viewer (live drawing canvas)

    @ViewBuilder
    private func annotationViewer(session: LiveAnnotationSession) -> some View {
        let sessionStrokes = store.annotation.liveSessions[session.id]?.strokes ?? [:]

        Image(decorative: session.frozenImage, scale: 1.0)
            .resizable()
            .scaledToFit()
            .overlay {
                // Remote peers' strokes — skip ones already rendered locally by PencilCanvas.
                AnnotationStrokesView(
                    strokes: sessionStrokes.values.filter { !localStrokeIDs.contains($0.id) }
                )
            }
            .overlay {
                PencilCanvas(
                    state:      canvasState,
                    brushColor: brushColor,
                    brushSize:  brushSize,
                    onAnnotationPoint: { strokeID, normalizedPoint, isStart, isEnd, r, g, b, lineWidth in
                        localStrokeIDs.insert(strokeID)
                        let msg = Annotation2DPointMessage(
                            sessionID: session.id,
                            strokeID:  strokeID,
                            x: Float(normalizedPoint.x),
                            y: Float(normalizedPoint.y),
                            isStart: isStart,
                            isEnd:   isEnd,
                            colorR: r, colorG: g, colorB: b,
                            lineWidth: lineWidth
                        )
                        store.sendAnnotationPoint(msg)
                    }
                )
            }
            .overlay(alignment: .bottom) {
                brushControls(sessionID: session.id)
            }
            .padding()
            .onChange(of: session.id) { _, _ in
                canvasState.clear()
                localStrokeIDs = []
            }
    }

    // MARK: - Brush controls overlay

    @ViewBuilder
    private func brushControls(sessionID: UUID) -> some View {
        HStack(spacing: 16) {
            ColorPicker("Color", selection: $brushColor, supportsOpacity: false)
                .labelsHidden()
                .frame(width: 36, height: 36)

            HStack(spacing: 8) {
                Image(systemName: "pencil.tip").foregroundStyle(.secondary)
                Slider(value: $brushSize, in: 1...20, step: 1)
                    .frame(width: 100)
                Text("\(Int(brushSize)) pt")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .frame(width: 36, alignment: .trailing)
            }

            Divider().frame(height: 24)

            Button {
                if let undoneID = canvasState.undo() {
                    localStrokeIDs.remove(undoneID)
                    store.removeAnnotationStrokes(sessionID: sessionID, ids: [undoneID])
                }
            } label: {
                Label("Undo", systemImage: "arrow.uturn.backward")
            }
            .labelStyle(.iconOnly)
            .disabled(canvasState.strokeCount == 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.bottom, 16)
    }

    // MARK: - Content router

    @ViewBuilder
    private func sharedContent(for examType: ExamType) -> some View {
        switch examType {
        case .echo, .ct, .coro:
            dicomViewer
        case .medicalHistory, .vitals, .bloodTests, .other:
            documentViewer(for: examType)
        }
    }

    // MARK: - DICOM viewer

    @ViewBuilder
    private var dicomViewer: some View {
        if let image = store.viewer.currentSliceImage {
            DICOMSliceViewer(
                image: image,
                sliceIndex: Binding(
                    get: { store.currentSliceIndex },
                    set: { store.currentSliceIndex = $0 }
                ),
                sliceCount: store.viewer.sliceCount
            )
            .background(.black)
        } else {
            ContentUnavailableView(
                "No DICOM Data",
                systemImage: "photo.slash",
                description: Text("This exam has not been loaded yet.")
            )
        }
    }

    // MARK: - Document viewer

    @ViewBuilder
    private func documentViewer(for examType: ExamType) -> some View {
        if let url = store.document.documentURL(for: examType) {
            PDFViewRepresentable(
                url: url,
                incomingState: store.document.sharedPDFState,
                onStateChange: { store.setLocalPDFState($0) }
            )
            .ignoresSafeArea()
        } else {
            ContentUnavailableView(
                "No \(examType.displayName) File",
                systemImage: "doc.slash",
                description: Text("Load \(examType.displayName) from the lobby to view it here.")
            )
        }
    }

    // MARK: - Placeholder

    private var placeholderView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 35)
                .stroke(style: StrokeStyle(lineWidth: 10))
                .padding(10)
                .foregroundStyle(.secondary.opacity(0.2))

            VStack(spacing: 15) {
                Image(systemName: "inset.filled.rectangle.and.person.filled")
                    .font(.system(size: 50))
                Text("Shared content will be visible for all participants in this window")
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(.secondary)
            .padding()
        }
    }
}

#Preview(windowStyle: .automatic) {
    NavigationStack {
        SharedWindow()
            .environment(AppStore())
    }
}
