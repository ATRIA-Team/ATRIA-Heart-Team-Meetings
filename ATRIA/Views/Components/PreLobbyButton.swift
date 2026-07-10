//
//  PreLobbyButton.swift
//  ATRIA
//
//  Created by Igor Tarantino on 22/05/2026.
//

import SwiftUI

struct PreLobbyButton: View {

    let icon: String
    let text: String
    let width: CGFloat
    let height: CGFloat
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            ZStack {
                Image(systemName: icon)
                    .font(.system(size: 75, weight: .bold))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.top, 30)
                    .padding(.trailing, 35)

                // Bottom label bar — plain material, no nested glassBackgroundEffect
                VStack {
                    Spacer()
                    UnevenRoundedRectangle(cornerRadii: .init(
                        topLeading: 0, bottomLeading: 20,
                        bottomTrailing: 20, topTrailing: 0
                    ))
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 50)
                }

                Text(text)
                    .font(.system(size: 20, weight: .bold))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 15)
            }
            .frame(width: width, height: height)
        }
        .buttonStyle(.plain)
        .buttonBorderShape(.roundedRectangle(radius: 20))
        .frame(width: width, height: height)
        .background(
            Color(red: 0.5, green: 0.5, blue: 0.5).opacity(0.6),
            in: RoundedRectangle(cornerRadius: 20)
        )
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 20))
    }
}

#Preview(windowStyle: .automatic) {
    PreLobbyButton(icon: "drop", text: "Blood Tests", width: 350, height: 200) {
        print("tapped")
    }
    .padding(40)
}
