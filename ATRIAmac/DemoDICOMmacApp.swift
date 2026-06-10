//
//  DemoDICOMmacApp.swift
//  DemoDICOMmac
//
//  Created by Igor Tarantino on 08/05/2026.
//

import SwiftUI

@main
struct DemoDICOMmacApp: App {
    @State private var store = FolderStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
        .commands {
            HelpCommands()
        }

        WindowGroup("Help", id: "help") {
            HelpView()
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 680, height: 620)
    }
}

private struct HelpCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .help) {
            Button("ATRIA Companion App Help") {
                openWindow(id: "help")
            }
            .keyboardShortcut("?", modifiers: .command)
        }
    }
}
