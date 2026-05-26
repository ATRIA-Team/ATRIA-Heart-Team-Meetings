//
//  ContentView.swift
//  DemoDICOM
//
//  Created by Michele Coppola on 25/03/2026.
//

import SwiftUI
import DicomCore
import UniformTypeIdentifiers

// MARK: - Window interaction disabler

/// Invisible UIView that finds its parent UIWindow and toggles
/// `isUserInteractionEnabled` so visionOS stops routing stylus
/// button presses as indirect-pointer clicks into this window.
struct WindowInteractionToggle: UIViewRepresentable {
    var enabled: Bool

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isHidden = true
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            uiView.window?.isUserInteractionEnabled = enabled
        }
    }
}

struct ContentView: View {

    @Environment(AppStore.self) private var store

    @Environment(\.openWindow) private var openWindow

    private enum ActivePicker { case folder, html, pdf }
    @State private var activePicker: ActivePicker? = nil
    @State private var isPickerPresented = false

    var body: some View {
        Group {
            if store.viewer.sliceImages.isEmpty && !store.viewer.isLoading {
                emptyStateView
            } else {
                sliceViewerView
            }
        }
        .navigationTitle("DICOM Viewer")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if store.viewer.loadedDICOMExamTypes.count > 1 {
                    Picker("Exam", selection: Binding(
                        get: { store.viewer.selectedDICOMExamType ?? .ct },
                        set: { store.viewer.selectedDICOMExamType = $0 }
                    )) {
                        ForEach(store.viewer.loadedDICOMExamTypes, id: \.self) { examType in
                            Text(examType.displayName).tag(examType)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                drawingToggleButton
                Button { activePicker = .html;   isPickerPresented = true } label: {
                    Label("Open HTML", systemImage: "doc.richtext")
                }
                Button { activePicker = .folder; isPickerPresented = true } label: {
                    Label("Import CT Scan", systemImage: "folder.badge.plus")
                }
                Button { activePicker = .pdf;    isPickerPresented = true } label: {
                    Label("Open PDF", systemImage: "rectangle.and.paperclip")
                }
            }
        }
        .fileImporter(
            isPresented: $isPickerPresented,
            allowedContentTypes: {
                switch activePicker {
                case .folder: return [.folder]
                case .html: return [.html]
                case .pdf, nil: return [.pdf]
                }
            }(),
            allowsMultipleSelection: false
        ) { result in
            defer { activePicker = nil }
            guard case .success(let urls) = result, let url = urls.first else {
                if case .failure(let error) = result {
                    store.viewer.errorMessage = "File picker error: \(error.localizedDescription)"
                }
                return
            }
            switch activePicker {
            case .folder: store.importFolder(url: url)
            case .html:
                store.document.htmlFileURL = url
                openWindow(id: "htmlViewer")
            case .pdf:
                store.document.pdfFileURL = url
                openWindow(id: "pdfViewer")
            case nil: break
            }
        }
        .overlay {
            if store.viewer.isLoading { loadingOverlay }
        }
        .alert(
            "Error",
            isPresented: Binding(
                get: { store.viewer.errorMessage != nil },
                set: { if !$0 { store.viewer.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.viewer.errorMessage ?? "")
        }
        // Disable window interaction while drawing so the stylus button
        // isn't intercepted as a pointer click by visionOS.
        .background {
            WindowInteractionToggle(enabled: !store.isDrawingActive)
        }
    }

    // MARK: - Subviews

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "doc.viewfinder")
                .font(.system(size: 72))
                .foregroundStyle(.secondary)

            Text("No CT Scan Loaded")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Import a folder containing DICOM (.dcm) files\nto view CT scan slices.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                activePicker = .folder
                isPickerPresented = true
            } label: {
                Label("Import CT Scan", systemImage: "folder.badge.plus")
                    .font(.headline)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var sliceViewerView: some View {
        HStack(alignment: .top, spacing: 0) {
            mainSliceContent
                .frame(maxWidth: .infinity)

            if store.annotation.isAnnotationPanelVisible {
                annotationPanel
                    .frame(width: 300)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.4), value: store.annotation.isAnnotationPanelVisible)
    }

    private var mainSliceContent: some View {
        VStack(spacing: 16) {
            metadataHeader

            if let cgImage = store.viewer.currentSliceImage {
                DICOMSliceViewer(
                    image: cgImage,
                    sliceIndex: Binding(
                        get: { store.currentSliceIndex },
                        set: { store.currentSliceIndex = $0 }
                    ),
                    sliceCount: store.viewer.sliceCount,
                    showInlineSlider: false
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(radius: 4)
                .frame(maxHeight: .infinity)
            }

            sliceControls
            presetPicker
        }
        .padding()
    }

    private var annotationPanel: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Label("Live Annotations", systemImage: "pencil.and.outline")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                // New annotation button — long-press on the slice is the primary way,
                // but this provides a quick shortcut from the sidebar.
                Button {
                    openWindow(id: "annotation", value: UUID())
                } label: {
                    Image(systemName: "plus")
                        .imageScale(.small)
                }
                .buttonStyle(.borderless)
                .help("Open new annotation")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)

            // One card per live session
            ScrollView {
                LazyVStack(spacing: 12) {
                    let sessions = store.annotation.liveSessions.values.sorted { $0.sliceIndex < $1.sliceIndex }
                    ForEach(sessions) { session in
                        annotationSessionCard(session)
                    }
                }
                .padding(12)
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.vertical, 8)
        .padding(.trailing, 8)
    }

    @ViewBuilder
    private func annotationSessionCard(_ session: LiveAnnotationSession) -> some View {
        VStack(spacing: 6) {
            // Frozen thumbnail with live strokes overlaid
            Image(decorative: session.frozenImage, scale: 1.0)
                .resizable()
                .scaledToFit()
                .overlay {
                    AnnotationStrokesView(strokes: Array(session.strokes.values))
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack {
                Text("Slice \(session.sliceIndex + 1)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    openWindow(id: "annotation", value: session.id)
                } label: {
                    Label("Open to Draw", systemImage: "pencil")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
        }
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private var metadataHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                if !store.viewer.patientName.isEmpty {
                    Label(store.viewer.patientName, systemImage: "person.fill")
                        .font(.headline)
                }
                if !store.viewer.studyDescription.isEmpty || !store.viewer.seriesDescription.isEmpty {
                    Text([store.viewer.studyDescription, store.viewer.seriesDescription]
                        .filter { !$0.isEmpty }
                        .joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if !store.viewer.modality.isEmpty {
                Text(store.viewer.modality)
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.blue.opacity(0.15), in: Capsule())
            }
        }
    }

    private var sliceControls: some View {
        VStack(spacing: 8) {
            if store.viewer.sliceCount > 1 {
                Slider(
                    value: Binding(
                        get: { Double(store.currentSliceIndex) },
                        set: { store.currentSliceIndex = Int($0) }
                    ),
                    in: 0...Double(max(store.viewer.sliceCount - 1, 1)),
                    step: 1
                )
            }

            Text("Slice \(store.currentSliceIndex + 1) / \(store.viewer.sliceCount)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private var presetPicker: some View {
        HStack {
            Text("Window Preset")
                .font(.subheadline)

            Spacer()

            // Manual Binding because @Environment doesn't expose $store in
            // computed properties — only inside body where @Bindable is declared.
            Picker("Preset", selection: Binding(
                get: { store.selectedPreset },
                set: { store.selectedPreset = $0 }
            )) {
                ForEach(DCMWindowingProcessor.ctPresets, id: \.self) { preset in
                    Text(preset.displayName).tag(preset)
                }
            }
            .pickerStyle(.menu)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    /// Toolbar button that opens / closes the mixed-immersion drawing space.
    /// RootView's onChange(of: store.isDrawingActive) handles the actual ImmersiveSpace.
    private var drawingToggleButton: some View {
        Button {
            store.isDrawingActive.toggle()
        } label: {
            Label(
                store.isDrawingActive ? "Stop Drawing" : "Draw",
                systemImage: store.isDrawingActive ? "pencil.slash" : "pencil.and.outline"
            )
        }
        .tint(store.isDrawingActive ? .orange : .primary)
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                Text("Loading DICOM slices…")
                    .font(.headline)
            }
            .padding(32)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        }
    }
}

// MARK: - AnnotationStrokesView

/// Renders normalized annotation strokes scaled to the view's actual size.
/// Used in the shared live-annotation panel so all participants see drawings in real time.
struct AnnotationStrokesView: View {
    let strokes: [AnnotationPanelStroke]

    var body: some View {
        Canvas { context, size in
            for stroke in strokes {
                guard stroke.points.count >= 2 else { continue }
                var path = Path()
                let first = stroke.points[0]
                path.move(to: CGPoint(x: first.x * size.width, y: first.y * size.height))
                for pt in stroke.points.dropFirst() {
                    path.addLine(to: CGPoint(x: pt.x * size.width, y: pt.y * size.height))
                }
                context.stroke(
                    path,
                    with: .color(stroke.color),
                    style: StrokeStyle(lineWidth: stroke.lineWidth, lineCap: .round, lineJoin: .round)
                )
            }
        }
    }
}

#Preview(windowStyle: .automatic) {
    NavigationStack {
        ContentView()
    }
    .environment(AppStore())
}
