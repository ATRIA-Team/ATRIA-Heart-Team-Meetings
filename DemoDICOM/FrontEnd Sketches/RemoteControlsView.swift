//
//  RemoteControlsView.swift
//  DemoDICOM
//
//  Created by Igor Tarantino on 06/05/2026.
//

import SwiftUI

struct RemoteControlsView: View {

    @Environment(DICOMStore.self) private var store
    @Environment(\.openWindow) private var openWindow

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
        }
        .padding(30)
    }

    // MARK: - Button builder

    @ViewBuilder
    private func remoteButton(_ examType: ExamType, icon: String, text: String) -> some View {
        let isShared = store.sharedWindowExamType == examType
        RemoteControlButton(
            icon: isShared ? "checkmark.circle.fill" : icon,
            text: text,
            action: { openLocally(examType) },
            longPressAction: { store.sharedWindowExamType = examType }
        )
    }

    // MARK: - Local action (quick pinch)

    private func openLocally(_ examType: ExamType) {
        switch examType {
        case .echo, .ct, .coro:
            store.selectedDICOMExamType = examType
        case .medicalHistory:
            if let url = store.medicalHistoryURL { openDocumentLocally(url) }
        case .vitals:
            if let url = store.vitalsURL { openDocumentLocally(url) }
        case .bloodTests:
            if let url = store.bloodTestURL { openDocumentLocally(url) }
        case .other:
            if let url = store.otherFileURL { openDocumentLocally(url) }
        }
    }

    private func openDocumentLocally(_ url: URL) {
        store.pdfFileURL = url
        openWindow(id: "pdfViewer")
    }
}

#Preview(windowStyle: .automatic) {
    RemoteControlsView()
        .environment(DICOMStore())
}
