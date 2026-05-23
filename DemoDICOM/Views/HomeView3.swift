//
//  HomeView3.swift
//  DemoDICOM
//
//  Created by Igor Tarantino on 21/05/2026.
//

import SwiftUI

struct HomeView3: View {
    
    @State private var isHovered = false
    
    var body: some View {
        
        ZStack {
            
            VStack(alignment: .leading) {
                
                HStack {
                    Text("Welcome to ATRIA")
                        .font(.largeTitle)
                    
                    Spacer()
                }
                .padding(50)
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("Pre - Op meeting")
                            .font(.title)
                        Text("ATRIA is your companion for pre-operative meetings. Start a meeting to begin!")
                            .font(.default)
                            .fontWeight(.light)
                            .padding(.bottom)
                        Button {
                            
                        } label: {
                            HStack {
                                Image(systemName: "video.fill")
                                Text("Start meeting")
                            }
                        }
                    }
                    .frame(width: 250)
                    .padding(.leading, 75)
                    
                    Spacer()
                    
                    Image("atrialogo1")
                        .padding(.trailing, 300)
                        .frame(width: 250, height: 150)
                }
                .padding(50)
                
                HStack(spacing: 30) {
                    HomeActionButton(icon: "eye.circle.fill", text: "DICOM Viewer", width: 350, height: 200) {
                    }
                    
                    HomeActionButton(icon: "document.on.document.fill", text: "Annotations", width: 350, height: 200) {
                    }
                }
                .padding(50)
            }
            
            VStack {
                Spacer()
                    .frame(height: 250)
                
                Image("Ellipse")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 1280, height: 240)
                    .mask(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: .black, location: 0.0),
                                .init(color: .clear, location: 0.6)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        }
    }
}

#Preview(windowStyle: .automatic) {
    HomeView3()
}
