//
//  HomeActionButton.swift
//  DemoDICOM
//
//  Created by Igor Tarantino on 22/05/2026.
//

import SwiftUI

struct HomeActionButton: View {

    let icon: String
    let text: String
    let width: CGFloat
    let height: CGFloat
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button {
            action()
        } label: {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.5, green: 0.5, blue: 0.5).opacity(1))
                .frame(width: width, height: height)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 2)
                .overlay(
                    ZStack {
                        Image(systemName: icon)
                            .font(.system(size: 75, weight: .bold))
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                            .padding(.top, 30)
                            .padding(.trailing, 35)

                        Text(text)
                            .font(.system(size: 20, weight: .bold))
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 15)
                    }
                    .allowsHitTesting(false)
                )
                .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 20))
//                .overlay(
//                    RoundedRectangle(cornerRadius: 20)
//                        .inset(by: 0.7)
//                        .stroke(
//                            LinearGradient(
//                                colors: [.white.opacity(0.4), .white.opacity(0.05)],
//                                startPoint: .topLeading,
//                                endPoint: .bottomTrailing
//                            ),
//                            lineWidth: 1.4
//                        )
//                )
                .overlay(
                    Group {
                        if isHovered {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white.opacity(0.15))
                        }
                    }
                )
        }
        .frame(width: width, height: height)
        .contentShape(RoundedRectangle(cornerRadius: 20))
        .buttonBorderShape(.roundedRectangle(radius: 20))
        .onHover { isHovered = $0 }
    }
}

#Preview(windowStyle: .automatic) {
    HomeActionButton(icon: "eye.circle.fill", text: "DICOM Visualizer", width: 350, height: 200) {
        print("tapped")
    }
    .padding(40)
}
