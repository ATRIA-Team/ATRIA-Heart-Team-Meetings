//
//  GlassCard.swift
//  DemoDICOMmac
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
