//
//  RemoteControls.swift
//  DemoDICOM
//
//  Created by Igor Tarantino on 06/05/2026.
//

import SwiftUI

struct RemoteControls: View {
    
    var body: some View {
        
        VStack(alignment: .leading, spacing: 30) {
            
            HStack(spacing: 30) {
                RemoteControlButton(icon: "list.bullet.clipboard.fill", text: "Medical History") { }
                RemoteControlButton(icon: "stethoscope", text:  "Vitals") { }
                RemoteControlButton(icon: "drop.fill", text:  "Blood Tests") { }
                RemoteControlButton(icon: "waveform.path.ecg.text.clipboard.fill", text:  "Echo") { }
            }
            
            HStack(spacing: 30) {
                RemoteControlButton(icon: "waveform.path.ecg.rectangle.fill", text:  "CT") { }
                RemoteControlButton(icon: "heart.fill", text:  "Coro") { }
                RemoteControlButton(icon: "heart.text.clipboard.fill", text:  "Other") { }
                RemoteControlButton(icon: "", text:  "") {
                    
                }
            }
            
            HStack {
                
                Image(systemName: "hand.pinch.fill")
                
                Text("Pinch to open a view locally • Pinch and hold to share to all participants.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview(windowStyle: .automatic) {
    RemoteControls()
}
