//
//  GlassCard.swift
//  ATRIAmac
//

import SwiftUI

struct GlassCard<Content: View>: View {

    enum Style {
        case panel
        case tile
    }

    var style: Style = .tile
    var cornerRadius: CGFloat = 20
    var isHighlighted: Bool = false
    var showHoverOverlay: Bool = false
    @ViewBuilder var content: () -> Content

    @Environment(\.colorScheme) private var colorScheme

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
        if colorScheme == .dark {
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
        } else {
            switch style {
            case .panel:
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
            case .tile:
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .opacity(isHighlighted ? 1.0 : 0.85)
            }
        }
    }

    private var gradientStroke: some View {
        let topOpacity: Double = colorScheme == .dark
            ? (isHighlighted ? 0.7 : 0.4)
            : (isHighlighted ? 0.5 : 0.3)
        let bottomOpacity: Double = colorScheme == .dark ? 0.05 : 0.15

        return RoundedRectangle(cornerRadius: cornerRadius)
            .inset(by: 0.7)
            .stroke(
                LinearGradient(
                    colors: [
                        Color.primary.opacity(topOpacity),
                        Color.primary.opacity(bottomOpacity)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1.4
            )
    }

    private var hoverOverlay: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(colorScheme == .dark ? Color.white.opacity(0.12) : Color.primary.opacity(0.05))
    }
}
