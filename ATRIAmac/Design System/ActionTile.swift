//
//  ActionTile.swift
//  DemoDICOMmac
//

import SwiftUI

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
