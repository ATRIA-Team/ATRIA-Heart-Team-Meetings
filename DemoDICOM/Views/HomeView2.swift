//
//  HomeView2.swift
//  DemoDICOM
//
//  Created by Igor Tarantino on 06/05/2026.
//

import SwiftUI
import GroupActivities
import _GroupActivities_UIKit

struct HomeView2: View {

    @Environment(AppStore.self) private var store

    @State private var noMeetings: Bool = true
    @State private var showCaptures: Bool = false
    @State private var showDICOMViewer: Bool = false
    @State private var showLobby: Bool = false
    @State private var showShareSheet: Bool = false

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
                    RemoteControlButton(icon: "folder.fill.badge.plus", text: "Upload Files") {
                        showLobby = true
                    }
                    RemoteControlButton(
                        icon: store.session.isInSession ? "shareplay" : "video.fill",
                        text: store.session.isInSession
                            ? "\(store.session.participantCount) in session"
                            : "Start meeting"
                    ) {
                        if store.session.isInSession {
                            // Already in a session — nothing to do from here.
                        } else {
                            showShareSheet = true
                        }
                    }
                    .sheet(isPresented: $showShareSheet) {
                        GroupActivitySharingSheet(activity: DICOMViewerActivity())
                            .ignoresSafeArea()
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
        .navigationDestination(isPresented: $showLobby) {
            LobbyView()
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

// MARK: - GroupActivitySharingSheet

/// Wraps `GroupActivitySharingController` so it can be presented as a SwiftUI sheet.
/// The system controller lets the user pick contacts, start a FaceTime call, and
/// share the activity — all in one flow.
private struct GroupActivitySharingSheet<Activity: GroupActivity>: UIViewControllerRepresentable {
    let activity: Activity

    func makeUIViewController(context: Context) -> UIViewController {
        (try? GroupActivitySharingController(activity)) ?? UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

#Preview(windowStyle: .automatic) {
    HomeView2()
}
