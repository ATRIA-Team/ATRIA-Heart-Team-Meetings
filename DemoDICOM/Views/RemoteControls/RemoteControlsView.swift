//
//  RemoteControlsView.swift
//  DemoDICOM
//

import SwiftUI

struct RemoteControlsView: View {

    @Environment(AppStore.self) private var store
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    // MARK: - File picker popover state

    private struct FilePickerTarget: Identifiable {
        enum Action { case open, push }
        let id = UUID()
        let examType: ExamType
        let action: Action
    }

    @State private var filePickerTarget: FilePickerTarget? = nil

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 30) {

            HStack(spacing: 30) {
                remoteButton(.medicalHistory, icon: "list.bullet.clipboard.fill", text: "Medical History")
                remoteButton(.vitals,         icon: "stethoscope",                text: "Vitals")
                remoteButton(.bloodTests,     icon: "drop.fill",                  text: "Blood Tests")
                remoteButton(.echo,           icon: "waveform.path.ecg.text.clipboard.fill", text: "Echo")
            }

            HStack(spacing: 30) {
                remoteButton(.ct,    icon: "waveform.path.ecg.rectangle.fill", text: "CT")
                remoteButton(.coro,  icon: "heart.fill",                        text: "Coro")
                remoteButton(.other, icon: "heart.text.clipboard.fill",         text: "Other")
            }

            HStack(spacing: 8) {
                Image(systemName: "hand.pinch.fill")
                Text("Pinch to open a view locally • Pinch and hold to share to all participants.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            drawingToolbar
        }
        .padding(30)
        .popover(item: $filePickerTarget) { target in
            filePickerPopover(for: target)
        }
    }

    // MARK: - Drawing toolbar

    private var drawingToolbar: some View {
        @Bindable var drawing = store.drawing
        return HStack(spacing: 20) {

            Button {
                Task {
                    if store.isDrawingActive {
                        await dismissImmersiveSpace()
                        store.isDrawingActive = false
                    } else {
                        store.suppressDrawingToolsPanel = true
                        let result = await openImmersiveSpace(id: "DrawingSpace")
                        if case .opened = result { store.isDrawingActive = true }
                    }
                }
            } label: {
                Label(
                    store.isDrawingActive ? "Stop Drawing" : "Start Drawing",
                    systemImage: store.isDrawingActive ? "pencil.slash" : "pencil.and.outline"
                )
            }
            .tint(store.isDrawingActive ? .black.opacity(0.2) : .black.opacity(0.7))
            .buttonStyle(.bordered)

            Divider().frame(height: 28)

            ColorPicker("Brush Color", selection: $drawing.brushColor, supportsOpacity: false)
                .labelsHidden()
                .frame(width: 36, height: 36)

            HStack(spacing: 8) {
                Image(systemName: "pencil.tip")
                    .foregroundStyle(.secondary)
                Slider(value: $drawing.brushSize, in: 0.001...0.02, step: 0.001)
                    .frame(width: 120)
                Text(String(format: "%.0f mm", store.drawing.brushSize * 1000))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .frame(width: 44, alignment: .trailing)
            }

            Divider().frame(height: 28)

            Button {
                store.undo3DStroke()
            } label: {
                Label("Undo", systemImage: "arrow.uturn.backward")
            }
            .labelStyle(.iconOnly)
            .disabled(!store.drawing.canUndo)

            Button {
                store.redo3DStroke()
            } label: {
                Label("Redo", systemImage: "arrow.uturn.forward")
            }
            .labelStyle(.iconOnly)
            .disabled(!store.drawing.canRedo)

            Divider().frame(height: 28)

            Button(role: .destructive) {
                store.clearAllDrawings()
            } label: {
                Label("Clear All", systemImage: "trash")
            }
            .labelStyle(.iconOnly)
            .disabled(!store.isDrawingActive)
        }
    }

    // MARK: - Button builder

    @ViewBuilder
    private func remoteButton(_ examType: ExamType, icon: String, text: String) -> some View {
        let isShared = store.document.sharedWindowExamType == examType
        RemoteControlButton(
            icon: isShared ? "checkmark.circle.fill" : icon,
            text: text,
            action: {
                if hasMultipleFiles(examType) {
                    filePickerTarget = FilePickerTarget(examType: examType, action: .open)
                } else {
                    openLocally(examType)
                }
            },
            longPressAction: {
                if hasMultipleFiles(examType) {
                    filePickerTarget = FilePickerTarget(examType: examType, action: .push)
                } else {
                    store.pushToSharedWindow(examType)
                }
            }
        )
    }

    // MARK: - Multi-file detection

    private func hasMultipleFiles(_ examType: ExamType) -> Bool {
        switch examType {
        case .echo, .ct, .coro:
            return (store.viewer.dicomExams[examType]?.count ?? 0) > 1
        default:
            return store.document.documentURLs(for: examType).count > 1
        }
    }

    // MARK: - Local action (quick pinch, single file)

    private func openLocally(_ examType: ExamType) {
        switch examType {
        case .echo, .ct, .coro:
            store.viewer.selectedDICOMExamType = examType
        case .medicalHistory:
            if let url = store.document.documentURL(for: .medicalHistory) { openDocumentLocally(url) }
        case .vitals:
            if let url = store.document.documentURL(for: .vitals) { openDocumentLocally(url) }
        case .bloodTests:
            if let url = store.document.documentURL(for: .bloodTests) { openDocumentLocally(url) }
        case .other:
            if let url = store.document.documentURL(for: .other) { openDocumentLocally(url) }
        }
    }

    private func openDocumentLocally(_ url: URL) {
        store.document.pdfFileURL = url
        openWindow(id: "pdfViewer")
    }

    // MARK: - File picker popover content

    @ViewBuilder
    private func filePickerPopover(for target: FilePickerTarget) -> some View {
        let examType = target.examType
        NavigationStack {
            List {
                switch examType {
                case .echo, .ct, .coro:
                    let bundles = store.viewer.dicomExams[examType] ?? []
                    ForEach(bundles.indices, id: \.self) { index in
                        let bundle = bundles[index]
                        Button {
                            store.viewer.selectBundle(index: index, examType: examType)
                            if target.action == .push {
                                store.pushToSharedWindow(examType)
                            }
                            filePickerTarget = nil
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(bundle.seriesDescription.isEmpty ? "Scan \(index + 1)" : bundle.seriesDescription)
                                    .font(.body)
                                Text("\(bundle.sliceCount) slices")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                default:
                    let urls = store.document.documentURLs(for: examType)
                    ForEach(urls, id: \.self) { url in
                        Button {
                            if target.action == .open {
                                openDocumentLocally(url)
                            } else {
                                store.document.setActiveDocumentURL(url, examType: examType)
                                store.pushToSharedWindow(examType)
                            }
                            filePickerTarget = nil
                        } label: {
                            Text(url.lastPathComponent)
                                .font(.body)
                        }
                    }
                }
            }
            .navigationTitle(examType.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { filePickerTarget = nil }
                }
            }
        }
        .frame(width: 320, height: 360)
    }
}

#Preview(windowStyle: .automatic) {
    RemoteControlsView()
        .environment(AppStore())
}
