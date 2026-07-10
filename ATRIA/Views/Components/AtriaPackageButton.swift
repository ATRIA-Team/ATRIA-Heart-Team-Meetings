//
//  AtriaPackageButton.swift
//  ATRIA
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

    var body: some View {
        Button {
            action()
        } label: {
            ZStack {
                Image(systemName: "icloud.and.arrow.down")
                    .font(.system(size: 75, weight: .bold))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.top, 30)
                    .padding(.leading, 35)

                // Bottom label bar — plain fill, no nested glassBackgroundEffect
                VStack {
                    Spacer()
                    UnevenRoundedRectangle(cornerRadii: .init(
                        topLeading: 0, bottomLeading: 20,
                        bottomTrailing: 20, topTrailing: 0
                    ))
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 50)
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
            .frame(width: 350, height: 200)
        }
        .buttonStyle(.plain)
        .buttonBorderShape(.roundedRectangle(radius: 20))
        .frame(width: 350, height: 200)
        .background(Color.clear, in: RoundedRectangle(cornerRadius: 20))
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 20))
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
                    .font(.system(size: 14, weight: .bold))
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
