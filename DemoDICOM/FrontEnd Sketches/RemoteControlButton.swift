//
//  RemoteControlButton.swift
//  DemoDICOM
//
//  Created by Igor Tarantino on 06/05/2026.
//

import SwiftUI

struct RemoteControlButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Rectangle()
                .foregroundColor(.clear)
                .frame(width: 160, height: 160)
                .background(Color(red: 0.5, green: 0.5, blue: 0.5).opacity(0.3))
                .cornerRadius(20)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 2)
                .overlay(
                    ZStack {
                        VStack(spacing: 15) {
                            Image(systemName: icon)
                                .font(.system(size: 50, weight: .bold))
                            Text(label)
                        }
                        RoundedRectangle(cornerRadius: 20)
                            .inset(by: 0.7)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.4), .white.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.4
                            )
                    }
                )
        }
        .buttonStyle(.plain)
    }
}
