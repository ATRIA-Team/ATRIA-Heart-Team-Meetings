//
//  DesignSystem.swift
//  DemoDICOMmac
//

import SwiftUI
import AppKit

// MARK: - Glass card

/// Reusable glass-style card matching the visionOS visual language.
struct GlassCard<Content: View>: View {

    enum Style {
        /// Lighter frosted panel — matches HomeView2 sidebar glass.
        case panel
        /// Gray semi-transparent tile — matches RemoteControlButton glass.
        case tile
    }

    var style: Style = .tile
    var cornerRadius: CGFloat = 20
    var isHighlighted: Bool = false
    var showHoverOverlay: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            background
            gradientStroke
            if showHoverOverlay { hoverOverlay }
            content()
        }
    }

    @ViewBuilder
    private var background: some View {
        switch style {
        case .panel:
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color(red: 0.84, green: 0.84, blue: 0.84).opacity(0.45))
                .background(
                    Color.black.opacity(0.08)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                )
        case .tile:
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color(red: 0.5, green: 0.5, blue: 0.5).opacity(isHighlighted ? 0.44 : 0.28))
        }
    }

    private var gradientStroke: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .inset(by: 0.7)
            .stroke(
                LinearGradient(
                    colors: [.white.opacity(isHighlighted ? 0.7 : 0.4), .white.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1.4
            )
    }

    private var hoverOverlay: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.white.opacity(0.12))
    }
}

// MARK: - Action tile

/// Visual appearance of a share/action tile. Manages its own hover state.
struct ActionTileContent: View {
    let icon: String
    let text: String
    @State private var isHovered = false

    var body: some View {
        GlassCard(cornerRadius: 16, showHoverOverlay: isHovered) {
            VStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                Text(text)
                    .font(.system(size: 7))
                    .multilineTextAlignment(.center)
            }
            .padding(12)
        }
        .frame(width: 88, height: 68)
        .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 1)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
    }
}

/// A standalone button styled as a glass action tile.
struct ActionTile: View {
    let icon: String
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ActionTileContent(icon: icon, text: text)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Native share button

/// Wraps any label in a button that opens the macOS native share sheet anchored to itself.
struct NativeShareButton<Label: View>: View {
    let items: [Any]
    @ViewBuilder var label: () -> Label
    @State private var anchor: NSView?

    var body: some View {
        Button {
            guard let anchor else { return }
            let picker = NSSharingServicePicker(items: items)
            picker.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .minY)
        } label: {
            label()
        }
        .buttonStyle(.plain)
        .background(AnchorCapture(view: $anchor))
    }
}

private struct AnchorCapture: NSViewRepresentable {
    @Binding var view: NSView?

    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        DispatchQueue.main.async { self.view = v }
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
