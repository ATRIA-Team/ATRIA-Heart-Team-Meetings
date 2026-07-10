//
//  HomeView.swift
//  ATRIA
//
//  Created by Igor Tarantino on 21/05/2026.
//

import SwiftUI
import GroupActivities
import _GroupActivities_UIKit

struct HomeView: View {

    @Environment(AppStore.self) private var store

    @State private var showShareSheet = false
    @State private var showLobby = false
    @State private var showDICOMViewer = false
    @State private var showAnnotations = false
    @State private var showDisclaimer = false

    var body: some View {
        
        NavigationStack {
            
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
                                .frame(width: 200, height: 100)
                                .padding(.bottom)
                            Button {
                                showShareSheet = true
                            } label: {
                                HStack {
                                    Image(systemName: "video.fill")
                                    Text("Start meeting")
                                }
                                .padding()
                            }
                            .background(LinearGradient(colors: [Color.black.opacity(0.3), Color.black.opacity(0.1)], startPoint: .bottom, endPoint: .top))
                            .clipShape(Capsule())
                            .buttonStyle(.plain)
                            .glassBackgroundEffect()
                            .sheet(isPresented: $showShareSheet) {
                                GroupActivitySharingSheet(activity: DICOMViewerActivity())
                                    .ignoresSafeArea()
                            }
                        }
                        .frame(width: 250)
                        .padding(.leading, 75)

                        Spacer()

                        Image("atrialogo1")
                            .padding(.trailing, 300)
                            .frame(width: 250, height: 150)
                    }
                    .frame(height: 325)

                    HStack(spacing: 30) {
                        HomeActionButton(icon: "eye.circle.fill", text: "DICOM Viewer", width: 350, height: 200) {
                            showDICOMViewer = true
                        }

                        HomeActionButton(icon: "document.on.document.fill", text: "Annotations", width: 350, height: 200) {
                            showAnnotations = true
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
                .allowsHitTesting(false)
            }
            .onChange(of: store.session.isInSession) { _, isInSession in
                if isInSession { showLobby = true }
            }
            .navigationDestination(isPresented: $showLobby) {
                LobbyView()
            }
            .navigationDestination(isPresented: $showDICOMViewer) {
                ContentView()
            }
            .navigationDestination(isPresented: $showAnnotations) {
                SavedAnnotationsView()
            }
            .navigationDestination(isPresented: $showDisclaimer) {
                DisclaimerView()
            }
        }
    }
}

// MARK: - GroupActivitySharingSheet

private struct GroupActivitySharingSheet<Activity: GroupActivity>: UIViewControllerRepresentable {
    let activity: Activity

    func makeUIViewController(context: Context) -> UIViewController {
        (try? GroupActivitySharingController(activity)) ?? UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

#Preview(windowStyle: .automatic) {
    HomeView()
        .environment(AppStore())
}
