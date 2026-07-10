//
//  ShareRow.swift
//  ATRIAmac
//

import SwiftUI
import AppKit

struct ShareRow: View {
    @Environment(FolderStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Package Ready")
                .font(.headline)
                .padding(.leading, 2)

            HStack(spacing: 8) {
                NativeShareButton(items: [store.folderState.folderURL as Any]) {
                    ActionTileContent(icon: "square.and.arrow.up", text: "Share")
                }

                ActionTile(icon: "folder", text: "Show in Finder") {
                    if let url = store.folderState.folderURL {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                }

                ActionTile(icon: "icloud.and.arrow.up", text: "Upload to iCloud") {
                    store.moveToICloud()
                }
            }
        }
    }
}
