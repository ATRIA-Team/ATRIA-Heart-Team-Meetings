//
//  SharedWindow.swift
//  DemoDICOM
//
//  Created by Igor Tarantino on 07/05/2026.
//

import SwiftUI
import PDFKit

struct SharedWindow: View {

    @Environment(DICOMStore.self) private var store
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        @Bindable var store = store

        Group {
            if let sessionID = store.sharedAnnotationSessionID,
               let session = store.liveSessions[sessionID] {
                annotationViewer(session: session)
            } else if let examType = store.sharedWindowExamType {
                sharedContent(for: examType, store: store)
            } else {
                placeholderView
            }
        }
        .navigationTitle(sharedWindowTitle(store: store))
        .background {
            WindowInteractionToggle(enabled: !store.isDrawingActive)
        }
    }

    // MARK: - Navigation title

    private func sharedWindowTitle(store: DICOMStore) -> String {
        if let sessionID = store.sharedAnnotationSessionID,
           let session = store.liveSessions[sessionID] {
            return "Annotation — Slice \(session.sliceIndex + 1)"
        }
        return store.sharedWindowExamType?.displayName ?? "Shared Window"
    }

    // MARK: - Annotation viewer

    @ViewBuilder
    private func annotationViewer(session: LiveAnnotationSession) -> some View {
        Image(decorative: session.frozenImage, scale: 1.0)
            .resizable()
            .scaledToFit()
            .overlay {
                AnnotationStrokesView(strokes: Array(session.strokes.values))
            }
            .padding()
    }

    // MARK: - Content router

    @ViewBuilder
    private func sharedContent(for examType: ExamType, store: DICOMStore) -> some View {
        switch examType {
        case .echo, .ct, .coro:
            dicomViewer(store: store)
        case .medicalHistory, .vitals, .bloodTests, .other:
            documentViewer(for: examType, store: store)
        }
    }

    // MARK: - DICOM viewer

    @ViewBuilder
    private func dicomViewer(store: DICOMStore) -> some View {
        @Bindable var store = store
        if let image = store.currentSliceImage {
            VStack(spacing: 0) {
                Image(image, scale: 1, label: Text("DICOM Slice"))
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.black)
                    .onLongPressGesture(minimumDuration: 0.5) {
                        openWindow(id: "annotation", value: UUID())
                    }
                    .overlay(alignment: .bottomTrailing) {
                        Label("Hold to annotate", systemImage: "pencil.and.outline")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(6)
                    }

                if store.sliceCount > 1 {
                    Slider(
                        value: Binding(
                            get: { Double(store.currentSliceIndex) },
                            set: { store.currentSliceIndex = Int($0) }
                        ),
                        in: 0...Double(store.sliceCount - 1),
                        step: 1
                    )
                    .padding()
                    .background(.ultraThinMaterial)
                }
            }
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
    private func documentViewer(for examType: ExamType, store: DICOMStore) -> some View {
        if let url = documentURL(for: examType, store: store) {
            PDFViewRepresentable(url: url)
                .ignoresSafeArea()
        } else {
            ContentUnavailableView(
                "No \(examType.displayName) File",
                systemImage: "doc.slash",
                description: Text("Load \(examType.displayName) from the lobby to view it here.")
            )
        }
    }

    private func documentURL(for examType: ExamType, store: DICOMStore) -> URL? {
        switch examType {
        case .medicalHistory: return store.medicalHistoryURL
        case .vitals:         return store.vitalsURL
        case .bloodTests:     return store.bloodTestURL
        case .other:          return store.otherFileURL
        default:              return nil
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
            .environment(DICOMStore())
    }
}
