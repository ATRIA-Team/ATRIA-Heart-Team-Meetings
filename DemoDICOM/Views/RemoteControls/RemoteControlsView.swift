//
//  RemoteControlsView.swift
//  DemoDICOM
//
//  Created by Igor Tarantino on 06/05/2026.
//

import SwiftUI

struct RemoteControlsView: View {

    @Environment(AppStore.self) private var store
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    var body: some View {
        VStack(alignment: .leading, spacing: 30) {

            HStack(spacing: 30) {
                remoteButton(.medicalHistory, icon: "list.bullet.clipboard.fill", text: "Medical History")
                remoteButton(.vitals,         icon: "stethoscope",                text: "Vitals")
                remoteButton(.bloodTests,     icon: "drop.fill",                  text: "Blood Tests")
                remoteButton(.echo,           icon: "waveform.path.ecg.text.clipboard.fill", text: "Echo")
            }

            HStack(spacing: 30) {
                remoteButton(.ct,   icon: "waveform.path.ecg.rectangle.fill", text: "CT")
                remoteButton(.coro, icon: "heart.fill",                        text: "Coro")
                remoteButton(.other, icon: "heart.text.clipboard.fill",        text: "Other")
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
            .tint(store.isDrawingActive ? .orange : .accentColor)
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
            action: { openLocally(examType) },
            longPressAction: { store.pushToSharedWindow(examType) }
        )
    }

    // MARK: - Local action (quick pinch)

    private func openLocally(_ examType: ExamType) {
        switch examType {
        case .echo, .ct, .coro:
            store.viewer.selectedDICOMExamType = examType
        case .medicalHistory:
            if let url = store.document.medicalHistoryURL { openDocumentLocally(url) }
        case .vitals:
            if let url = store.document.vitalsURL { openDocumentLocally(url) }
        case .bloodTests:
            if let url = store.document.bloodTestURL { openDocumentLocally(url) }
        case .other:
            if let url = store.document.otherFileURL { openDocumentLocally(url) }
        }
    }

    private func openDocumentLocally(_ url: URL) {
        store.document.pdfFileURL = url
        openWindow(id: "pdfViewer")
    }
}

#Preview(windowStyle: .automatic) {
    RemoteControlsView()
        .environment(AppStore())
}
