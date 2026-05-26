//
//  AnnotationView.swift
//  DemoDICOM
//

import SwiftUI
import SwiftData
import UIKit

/// A dedicated 2-D annotation window opened from the slice viewer.
///
/// Each window is tied to a `sessionID` which identifies one `LiveAnnotationSession`
/// in `AnnotationStore.liveSessions`. The session holds a frozen `CGImage` — the DICOM
/// slice as it appeared at the moment the annotation was opened — so scrolling the
/// main viewer's slider or changing the preset has no effect on this canvas.
///
/// Multiple windows (for different sessions) can be open simultaneously. Opening the
/// same session ID a second time focuses the existing window rather than creating a
/// duplicate, thanks to visionOS `WindowGroup(id:for:)` behaviour.
struct AnnotationView: View {

    /// The session this window belongs to.
    let sessionID: UUID

    @Environment(AppStore.self) private var store
    @Environment(\.modelContext) private var modelContext

    @State private var canvasState = PencilCanvasState()
    @State private var brushColor: Color   = .red
    @State private var brushSize:  CGFloat = 3.0
    @State private var showSavedConfirmation = false
    /// Stroke IDs produced by THIS device's PencilCanvas.
    /// Used to skip them in AnnotationStrokesView so they aren't double-rendered.
    @State private var localStrokeIDs: Set<UUID> = []
    /// The frozen DICOM image captured when the session was created or joined.
    /// Stored in @State so it survives any store mutations (preset changes, slider).
    @State private var frozenImage: CGImage? = nil

    var body: some View {
        NavigationStack {
            contentArea
                .navigationTitle(navigationTitle)
                .toolbar { toolbarContent }
                .overlay(alignment: .top) {
                    if showSavedConfirmation { savedBanner }
                }
        }
        .onAppear {
            localStrokeIDs = []
            if store.annotation.liveSessions[sessionID] == nil {
                // Brand-new session: freeze current slice and register with the store.
                if let image = store.viewer.currentSliceImage {
                    frozenImage = image
                    store.createAnnotationSession(
                        id: sessionID,
                        sliceIndex: store.currentSliceIndex,
                        image: image
                    )
                }
            } else {
                // Joining an existing session from the sidebar.
                frozenImage = store.annotation.liveSessions[sessionID]?.frozenImage
                store.joinAnnotationSession(id: sessionID)
            }
        }
        .onDisappear {
            store.closeAnnotationSession(id: sessionID)
        }
    }

    // MARK: - Helpers

    private var navigationTitle: String {
        if let session = store.annotation.liveSessions[sessionID] {
            return "Annotate — Slice \(session.sliceIndex + 1)"
        }
        return "Annotate"
    }

    // MARK: - Content area

    @ViewBuilder
    private var contentArea: some View {
        // Use the captured frozen image; fall back to the store value briefly
        // on the first render before onAppear has fired.
        let displayImage = frozenImage ?? store.annotation.liveSessions[sessionID]?.frozenImage

        if let cgImage = displayImage {
            let sessionStrokes = store.annotation.liveSessions[sessionID]?.strokes ?? [:]
            Image(decorative: cgImage, scale: 1.0)
                .resizable()
                .scaledToFit()
                .overlay {
                    // Remote strokes — skip local ones already rendered by PencilCanvas.
                    AnnotationStrokesView(
                        strokes: sessionStrokes.values.filter {
                            !localStrokeIDs.contains($0.id)
                        }
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
                                sessionID: sessionID,
                                strokeID: strokeID,
                                x: Float(normalizedPoint.x),
                                y: Float(normalizedPoint.y),
                                isStart: isStart,
                                isEnd: isEnd,
                                colorR: r, colorG: g, colorB: b,
                                lineWidth: lineWidth
                            )
                            store.sendAnnotationPoint(msg)
                        }
                    )
                }
                .overlay(alignment: .bottom) {
                    if canvasState.strokeCount == 0 {
                        Text("Draw with spatial pen or finger")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding(.bottom, 12)
                    }
                }
                .padding()
        } else {
            ContentUnavailableView(
                "No slice loaded",
                systemImage: "doc.viewfinder",
                description: Text("Import a DICOM folder in the main viewer first.")
            )
        }
    }

    // MARK: - Save

    private func saveAnnotation() {
        guard let cgImage = frozenImage ?? store.annotation.liveSessions[sessionID]?.frozenImage,
              let base = canvasState.snapshot(backgroundCGImage: cgImage) else { return }

        let sessionStrokes = store.annotation.liveSessions[sessionID]?.strokes ?? [:]
        let remoteStrokes = sessionStrokes.values.filter { !localStrokeIDs.contains($0.id) }

        let finalImage: UIImage
        if remoteStrokes.isEmpty {
            finalImage = base
        } else {
            let size = base.size
            let renderer = UIGraphicsImageRenderer(size: size)
            finalImage = renderer.image { _ in
                base.draw(at: .zero)
                for stroke in remoteStrokes {
                    guard stroke.points.count >= 2 else { continue }
                    let path = UIBezierPath()
                    path.move(to: CGPoint(x: stroke.points[0].x * size.width,
                                         y: stroke.points[0].y * size.height))
                    for pt in stroke.points.dropFirst() {
                        path.addLine(to: CGPoint(x: pt.x * size.width, y: pt.y * size.height))
                    }
                    path.lineWidth = stroke.lineWidth
                    path.lineCapStyle = .round
                    path.lineJoinStyle = .round
                    UIColor(stroke.color).setStroke()
                    path.stroke()
                }
            }
        }

        guard let pngData = finalImage.pngData() else { return }

        let sliceIndex = store.annotation.liveSessions[sessionID]?.sliceIndex ?? store.currentSliceIndex
        let annotation = SavedAnnotation(
            sliceIndex:         sliceIndex,
            patientName:        store.viewer.patientName,
            seriesDescription:  store.viewer.seriesDescription,
            imageData:          pngData
        )
        modelContext.insert(annotation)

        withAnimation { showSavedConfirmation = true }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { showSavedConfirmation = false }
        }
    }

    // MARK: - Saved banner

    private var savedBanner: some View {
        Label("Saved to Annotations", systemImage: "checkmark.circle.fill")
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.green.gradient, in: Capsule())
            .padding(.top, 12)
            .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {

        ToolbarItemGroup(placement: .topBarLeading) {
            ColorPicker("Color", selection: $brushColor, supportsOpacity: false)
                .labelsHidden()

            HStack(spacing: 8) {
                Image(systemName: "pencil.tip")
                    .foregroundStyle(.secondary)
                Slider(value: $brushSize, in: 1...20, step: 1)
                    .frame(width: 120)
                Text("\(Int(brushSize)) pt")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .frame(width: 36, alignment: .trailing)
            }
        }

        ToolbarItemGroup(placement: .topBarTrailing) {
            let isSharing = store.document.sharedAnnotationSessionID == sessionID
            Button {
                store.setSharedAnnotation(isSharing ? nil : sessionID)
            } label: {
                HStack {
                    Image(systemName: isSharing ? "checkmark.circle.fill" : "shareplay")
                    Text(isSharing ? "Sharing" : "Share annotation")
                }
            }
            Button {
                saveAnnotation()
            } label: {
                Label("Save", systemImage: "square.and.arrow.down")
            }

            Button {
                if let undoneID = canvasState.undo() {
                    localStrokeIDs.remove(undoneID)
                    store.removeAnnotationStrokes(sessionID: sessionID, ids: [undoneID])
                }
            } label: {
                Label("Undo", systemImage: "arrow.uturn.backward")
            }
            .disabled(canvasState.strokeCount == 0)

            Button(role: .destructive) {
                let ids = localStrokeIDs
                store.removeAnnotationStrokes(sessionID: sessionID, ids: ids)
                canvasState.removeStrokes(ids: ids)
                localStrokeIDs = []
            } label: {
                Label("Clear my strokes", systemImage: "trash")
            }
            .disabled(localStrokeIDs.isEmpty)
        }
    }
}

#Preview {
    // Build a mock CGImage (grey gradient, 512×512) that stands in for a DICOM slice.
    let previewImage: CGImage = {
        let width = 512, height = 512
        let ctx = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        for y in 0..<height {
            let brightness = CGFloat(y) / CGFloat(height)
            ctx.setFillColor(CGColor(gray: brightness, alpha: 1))
            ctx.fill(CGRect(x: 0, y: y, width: width, height: 1))
        }
        return ctx.makeImage()!
    }()

    // Seed the store with a live annotation session so the view renders its canvas.
    let store = AppStore()
    let sessionID = UUID()
    store.createAnnotationSession(id: sessionID, sliceIndex: 4, image: previewImage)

    let container = try! ModelContainer(for: SavedAnnotation.self, configurations: .init(isStoredInMemoryOnly: true))

    return AnnotationView(sessionID: sessionID)
        .environment(store)
        .modelContainer(container)
}
