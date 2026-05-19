//
//  ContentView.swift
//  DemoDICOMmac
//

import SwiftUI
import AppKit

struct ContentView: View {
    @Environment(FolderStore.self) private var store
    @State private var folderName = "Patient Folder"

    var body: some View {
        HStack(alignment: .top, spacing: 28) {
            VStack(alignment: .leading, spacing: 14) {
                SidePanel(folderName: $folderName, onCreateTapped: chooseLocationAndCreate)
                if store.folderState.folderURL != nil {
                    ShareRow()
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    DropTile(category: .medicalHistory)
                    DropTile(category: .vitals)
                    DropTile(category: .bloodTests)
                    DropTile(category: .echo)
                }
                HStack(spacing: 14) {
                    DropTile(category: .ct)
                    DropTile(category: .coro)
                    DropTile(category: .other)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(30)
        .frame(minWidth: 1080, minHeight: 560)
    }

    private func chooseLocationAndCreate() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.message = "Choose where to create the folder"
        panel.directoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        guard panel.runModal() == .OK, let parent = panel.url else { return }
        store.createFolder(named: folderName, in: parent)
    }
}

#Preview {
    let store = FolderStore()
    store.files[.medicalHistory] = [URL(fileURLWithPath: "/mock/patient_history.pdf")]
    store.files[.vitals]         = [URL(fileURLWithPath: "/mock/vitals_2026.pdf")]
    store.files[.bloodTests]     = [URL(fileURLWithPath: "/mock/blood_results.pdf"), URL(fileURLWithPath: "/mock/cbc_panel.pdf")]
    store.files[.echo]           = [URL(fileURLWithPath: "/mock/echo_study.dcm")]
    store.files[.ct]             = [URL(fileURLWithPath: "/mock/ct_chest_001.dcm"), URL(fileURLWithPath: "/mock/ct_chest_002.dcm")]
    store.files[.coro]           = [URL(fileURLWithPath: "/mock/coro_left.dcm")]
    store.files[.other]          = []
    store.folderState            = .ready(URL(fileURLWithPath: "/mock/Patient Folder"))

    return ContentView()
        .environment(store)
}
