//
//  DICOMSliceViewer.swift
//  DemoDICOM
//

import SwiftUI
import CoreGraphics

/// Renders a single DICOM slice image with long-press-to-annotate support
/// and an optional inline slice slider.
///
/// Used by both `ContentView` (standalone viewer, `showInlineSlider: false`)
/// and `SharedWindow` (shared hub, `showInlineSlider: true`).
struct DICOMSliceViewer: View {

    let image: CGImage
    @Binding var sliceIndex: Int
    let sliceCount: Int

    /// When true, a slider is shown below the image (SharedWindow style).
    /// When false, the caller manages slice navigation separately (ContentView style).
    var showInlineSlider: Bool = true
    var showAnnotateHint: Bool = true

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            Image(decorative: image, scale: 1.0)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onLongPressGesture(minimumDuration: 0.5) {
                    openWindow(id: "annotation", value: UUID())
                }
                .overlay(alignment: .bottomTrailing) {
                    if showAnnotateHint {
                        Label("Hold to annotate", systemImage: "pencil.and.outline")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(6)
                    }
                }

            if showInlineSlider && sliceCount > 1 {
                Slider(
                    value: Binding(
                        get: { Double(sliceIndex) },
                        set: { sliceIndex = Int($0) }
                    ),
                    in: 0...Double(max(sliceCount - 1, 1)),
                    step: 1
                )
                .padding()
                .background(.ultraThinMaterial)
            }
        }
    }
}
