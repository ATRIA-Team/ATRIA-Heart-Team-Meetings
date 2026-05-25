//
//  AtriaPackageButton.swift
//  DemoDICOM
//
//  Created by Igor Tarantino on 25/05/2026.
//

import SwiftUI

enum AtriaPackageButtonState {
    case waiting
    case uploaded
    case mismatch
}

struct AtriaPackageButton: View {

    let state: AtriaPackageButtonState
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button {
            action()
        } label: {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.5, green: 0.5, blue: 0.5).opacity(1))
                .frame(width: 350, height: 200)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 2)
                .overlay(
                    ZStack {
                        Image(systemName: "icloud.and.arrow.down")
                            .font(.system(size: 75, weight: .bold))
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .padding(.top, 30)
                            .padding(.leading, 35)

                        VStack {
                            Spacer()
                            UnevenRoundedRectangle(cornerRadii: .init(topLeading: 10, bottomLeading: 20, bottomTrailing: 20, topTrailing: 10))
                                .frame(height: 55)
                                .foregroundStyle(Color.gray)
                                .overlay(
                                    UnevenRoundedRectangle(cornerRadii: .init(topLeading: 10, bottomLeading: 20, bottomTrailing: 20, topTrailing: 10))
                                        .stroke(
                                            LinearGradient(
                                                colors: [.white.opacity(0.3), .white.opacity(0.1)],
                                                startPoint: .topLeading,
                                                endPoint: .topTrailing
                                            ),
                                            lineWidth: 1.4
                                        )
                                )
                        }

                        Text("Load .atria Package")
                            .font(.system(size: 20, weight: .bold))
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 15)

                        if state != .waiting {
                            statusBadge
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                                .padding()
                        }
                    }
                )
                .overlay(
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
                )
                .overlay(
                    Group {
                        if isHovered {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white.opacity(0.15))
                        }
                    }
                )
        }
        .frame(width: 350, height: 200)
        .contentShape(RoundedRectangle(cornerRadius: 20))
        .buttonBorderShape(.roundedRectangle(radius: 20))
        .onHover { isHovered = $0 }
    }

    @ViewBuilder
    private var statusBadge: some View {
        HStack(spacing: 6) {
            Text(state == .uploaded ? "Files uploaded" : "File mismatch")
                .fontWeight(.medium)

            ZStack {
                Circle()
                    .foregroundStyle(Color.gray)
                    .frame(width: 30, height: 30)

                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.3), .white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .topTrailing
                        ),
                        lineWidth: 1.4
                    )
                    .frame(width: 30, height: 30)

                Image(systemName: state == .uploaded ? "checkmark" : "exclamationmark.triangle")
                    .foregroundStyle(state == .uploaded ? Color.green : Color.yellow)
                    .font(.system(size: 17, weight: .bold))
            }
        }
    }
}

#Preview(windowStyle: .automatic) {
    VStack(alignment: .leading, spacing: 24) {
        Text("Waiting").font(.caption).foregroundStyle(.secondary)
        AtriaPackageButton(state: .waiting) { }

        Text("Uploaded").font(.caption).foregroundStyle(.secondary)
        AtriaPackageButton(state: .uploaded) { }

        Text("Mismatch").font(.caption).foregroundStyle(.secondary)
        AtriaPackageButton(state: .mismatch) { }
    }
    .padding(40)
}
