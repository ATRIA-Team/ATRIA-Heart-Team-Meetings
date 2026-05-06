//
//  HomeView2.swift
//  DemoDICOM
//
//  Created by Igor Tarantino on 06/05/2026.
//

import SwiftUI

struct HomeView2: View {

    @Environment(DICOMStore.self) private var store

    @State private var noMeetings: Bool = true
    @State private var showCaptures: Bool = false
    @State private var showDICOMViewer: Bool = false

    var body: some View {
        NavigationStack {
        HStack(spacing: 150) {
            
            Rectangle()
                .foregroundColor(.clear)
                .frame(width: 482, height: 586)
                .background(.black.opacity(0.08))
                .background(Color(red: 0.84, green: 0.84, blue: 0.84).opacity(0.45))
                .cornerRadius(100)
                .overlay {
                    
                    VStack(spacing: 35) {
                        
                        VStack(spacing: 1) {
                            Text("09:41")
                                .font(.system(size: 50, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("01 Jun 2026")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                        }
                        .padding(.top, 25)
                        
                        Text("Upcoming meetings")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(.white)
                        
                        if noMeetings {
                            
                            VStack {
                                Image(systemName: "video.slash")
                                    .font(.system(size: 50))
                                
                                Text("There are no scheduled meetings")
                                    .font(.callout)
                            }
                            .foregroundStyle(.secondary)
                            .padding(.top, 85)
                            
                        } else {
                            
                        }
                        
                        Spacer()
                    }
                }
            
            VStack(spacing: 30) {

                HStack(spacing: 30) {
                    RemoteControlButton(icon: "folder.fill.badge.plus", text: "Upload Files") {}
                    RemoteControlButton(
                        icon: store.sharePlay.isInSession ? "shareplay" : "video.fill",
                        text: store.sharePlay.isInSession
                            ? "\(store.sharePlay.participantCount) in session"
                            : (store.sharePlay.isEligibleForGroupSession ? "Invite to SharePlay" : "Start meeting")
                    ) {
                        Task { await store.sharePlay.activate() }
                    }
                }

                HStack(spacing: 30) {
                    RemoteControlButton(icon: "document.on.document.fill", text: "Captures") {
                        showCaptures = true
                    }
                    RemoteControlButton(icon: "eye.circle.fill", text: "DICOM viewer") {
                        showDICOMViewer = true
                    }
                }
            }
        }
        .alert(
            "SharePlay Unavailable",
            isPresented: Binding(
                get: { store.sharePlay.activationError != nil },
                set: { if !$0 { store.sharePlay.activationError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.sharePlay.activationError ?? "")
        }
        .navigationDestination(isPresented: $showCaptures) {
            SavedAnnotationsView()
        }
        .navigationDestination(isPresented: $showDICOMViewer) {
            ContentView()
        }
        } // NavigationStack
    }
}

#Preview(windowStyle: .automatic) {
    HomeView2()
}
