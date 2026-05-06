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
                RemoteControlButton(icon: "list.bullet.clipboard.fill", label: "Medical History") { }
                RemoteControlButton(icon: "stethoscope", label: "Vitals") { }
                RemoteControlButton(icon: "drop.fill", label: "Blood Tests") { }
                RemoteControlButton(icon: "waveform.path.ecg.text.clipboard.fill", label: "Echo") { }
            }
            
            HStack(spacing: 30) {
                RemoteControlButton(icon: "waveform.path.ecg.rectangle.fill", label: "CT") { }
                RemoteControlButton(icon: "heart.fill", label: "Coro") { }
                RemoteControlButton(icon: "heart.text.clipboard.fill", label: "Other") { }
                RemoteControlButton(icon: "", label: "") {
                    
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
