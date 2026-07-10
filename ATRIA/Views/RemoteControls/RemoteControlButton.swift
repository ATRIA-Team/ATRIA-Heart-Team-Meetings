//
//  RemoteControlButton.swift
//  ATRIA
//
//  Created by Igor Tarantino on 06/05/2026.
//

import SwiftUI

struct RemoteControlButton: View {

    let icon: String
    let text: String
    let action: () -> Void
    var longPressAction: (() -> Void)? = nil
    @State private var isHovered = false
    @State private var longPressTriggered = false

    var body: some View {

        let button = Button {
            if !longPressTriggered {
                action()
            }
            longPressTriggered = false
        } label: {
            
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

                            Text(text)
                        }

//                        RoundedRectangle(cornerRadius: 20)
//                            .inset(by: 0.7)
//                            .stroke(
//
//                                LinearGradient(
//                                    colors: [.white.opacity(0.4), .white.opacity(0.05)],
//                                    startPoint: .topLeading,
//                                    endPoint: .bottomTrailing
//                                ),
//                                lineWidth: 1.4
//                            )

                        if isHovered {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white.opacity(0.15))
                        }
                    }
                )
        }
        .frame(width: 160, height: 160)
//        .contentShape(RoundedRectangle(cornerRadius: 20))
//        .glassBackgroundEffect()
        .buttonBorderShape(.roundedRectangle(radius: 20))
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 20))

        if let longPressAction {
            button.simultaneousGesture(
                LongPressGesture(minimumDuration: 0.6).onEnded { _ in
                    longPressTriggered = true
                    longPressAction()
                }
            )
        } else {
            button
        }
    }
}

#Preview(windowStyle: .automatic) {
    RemoteControlsView()
        .environment(AppStore())
}
