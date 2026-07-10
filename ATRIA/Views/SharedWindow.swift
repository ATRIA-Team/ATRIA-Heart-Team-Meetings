//
//  SharedWindow.swift
//  ATRIA
//
//  Created by Igor Tarantino on 07/05/2026.
//

import SwiftUI
import PDFKit
import DicomCore

struct SharedWindow: View {

    @Environment(AppStore.self) private var store
    @Environment(\.openWindow) private var openWindow

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
        .ornament(
            visibility: store.document.sharedAnnotationSessionID != nil
                ? .hidden
                : (store.viewer.sliceCount > 1 && isDICOMExamType(store.document.sharedWindowExamType) ? .visible : .hidden),
            attachmentAnchor: .scene(.bottom)
        ) {
            VStack(spacing: 4) {
                Slider(
                    value: Binding(
                        get: { Double(store.currentSliceIndex) },
                        set: { store.currentSliceIndex = Int($0) }
                    ),
                    in: 0...Double(max(store.viewer.sliceCount - 1, 1)),
                    step: 1
                )
                .frame(width: 400)
                Text("Slice \(store.currentSliceIndex + 1) / \(store.viewer.sliceCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .glassBackgroundEffect()
        }
        .ornament(
            visibility: store.document.sharedAnnotationSessionID != nil ? .visible : .hidden,
            attachmentAnchor: .scene(.bottom)
        ) {
            if let sessionID = store.document.sharedAnnotationSessionID {
                brushControls(sessionID: sessionID)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .glassBackgroundEffect()
            }
        }
        .navigationTitle(isDICOMExamType(store.document.sharedWindowExamType) ? "" : sharedWindowTitle)
        .toolbar {
            if isDICOMExamType(store.document.sharedWindowExamType) {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 8) {
                        Image("atrialogo1")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 28)
                        Text("DICOM Viewer")
                            .font(.headline)
                    }
                }

                ToolbarItem(placement: .principal) {
                    Text(store.viewer.patientName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 10) {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil.and.outline")
                            Text("Pinch and Hold image to Annotate")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        Divider().frame(height: 16)

                        Menu {
                            ForEach(DCMWindowingProcessor.ctPresets, id: \.self) { preset in
                                Button {
                                    store.selectedPreset = preset
                                } label: {
                                    if preset == store.selectedPreset {
                                        Label(preset.displayName, systemImage: "checkmark")
                                    } else {
                                        Text(preset.displayName)
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(store.selectedPreset.displayName)
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
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
            VStack(spacing: 0) {
                DICOMSliceViewer(
                    image: image,
                    sliceIndex: Binding(
                        get: { store.currentSliceIndex },
                        set: { store.currentSliceIndex = $0 }
                    ),
                    sliceCount: store.viewer.sliceCount,
                    showInlineSlider: false,
                    showAnnotateHint: false
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.black)

            }
        } else {
            ContentUnavailableView(
                "No DICOM Data",
                systemImage: "photo.slash",
                description: Text("This exam has not been loaded yet.")
            )
        }
    }

    private func isDICOMExamType(_ examType: ExamType?) -> Bool {
        guard let examType else { return false }
        switch examType {
        case .echo, .ct, .coro: return true
        default: return false
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
    let store = AppStore()

    let width = 512, height = 512

    func makeSlice(brightness: Double) -> CGImage {
        var slicePixels = [UInt8](repeating: 0, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                let dist = hypot(Double(x) - Double(width) / 2, Double(y) - Double(height) / 2)
                slicePixels[y * width + x] = UInt8(max(0, min(255, brightness - dist * 0.5)))
            }
        }
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let ctx = CGContext(
            data: &slicePixels,
            width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        )!
        return ctx.makeImage()!
    }

    let mockSlices = (0..<15).map { i in makeSlice(brightness: 180 + Double(i % 40)) }

    let bundle = DICOMExamBundle(
        sliceImages: mockSlices,
        rawPixelBuffers16: [],
        currentSliceIndex: 0,
        patientName: "Rossi Mario",
        studyDescription: "Chest CT",
        seriesDescription: "Axial 1.0mm",
        modality: "CT"
    )
    store.viewer.applyImportResult(bundle, examType: .ct)
    store.document.applySharedWindow(.ct)

    return NavigationStack {
        SharedWindow()
            .environment(store)
    }
}
