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
            Text("Share Folder")
                .font(.headline)
                .padding(.leading, 2)

            HStack(spacing: 8) {
                NativeShareButton(items: [model.createdFolderURL as Any]) {
                    ActionTileContent(icon: "square.and.arrow.up", text: "Share")
                }

                ActionTile(icon: "icloud.and.arrow.up", text: "Move to iCloud") {
                    if let moved = model.moveToICloud() { presentSharePicker(for: moved) }
                }

                ActionTile(icon: "folder", text: "Show in Finder") {
                    if let url = model.createdFolderURL {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                }
            }
        }
    }

    private func presentSharePicker(for url: URL) {
        let picker = NSSharingServicePicker(items: [url])
        guard let window = NSApp.keyWindow, let view = window.contentView else { return }
        let rect = NSRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
        picker.show(relativeTo: rect, of: view, preferredEdge: .minY)
    }
}
