//
//  ShareRow.swift
//  DemoDICOMmac
//

import SwiftUI
import AppKit

struct ShareRow: View {
    @ObservedObject var model: FolderModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Folder Ready")
                .font(.headline)
                .padding(.leading, 2)

            HStack(spacing: 8) {
                ActionTile(icon: "folder", text: "Show in Finder") {
                    if let url = model.createdFolderURL {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                }

                ActionTile(icon: "envelope.badge.person.crop", text: "Resend Email") {
                    model.shareViaEmailIfNeeded()
                }
                .disabled(model.collaboratorEmails.isEmpty)
            }
        }
    }
}
