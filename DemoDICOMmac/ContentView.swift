//
//  ContentView.swift
//  DemoDICOMmac
//
//  Created by Igor Tarantino on 08/05/2026.
//

import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var model: FolderModel
    @State private var folderName = "Patient Folder"

    init(previewModel: FolderModel? = nil) {
        _model = StateObject(wrappedValue: previewModel ?? FolderModel())
    }

    var body: some View {
        HStack(alignment: .top, spacing: 28) {
            VStack(alignment: .leading, spacing: 14) {
                SidePanel(model: model, folderName: $folderName, onCreateTapped: chooseLocationAndCreate)
                if model.createdFolderURL != nil {
                    ShareRow(model: model)
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    DropTile(category: .medicalHistory, model: model)
                    DropTile(category: .vitals,         model: model)
                    DropTile(category: .bloodTests,     model: model)
                    DropTile(category: .echo,           model: model)
                }
                HStack(spacing: 14) {
                    DropTile(category: .ct,    model: model)
                    DropTile(category: .coro,  model: model)
                    DropTile(category: .other, model: model)
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
        model.createFolder(named: folderName, in: parent)
    }
}

#Preview {
    let model = FolderModel()
    model.files[.medicalHistory] = [URL(fileURLWithPath: "/mock/patient_history.pdf")]
    model.files[.vitals]         = [URL(fileURLWithPath: "/mock/vitals_2026.pdf")]
    model.files[.bloodTests]     = [URL(fileURLWithPath: "/mock/blood_results.pdf"), URL(fileURLWithPath: "/mock/cbc_panel.pdf")]
    model.files[.echo]           = [URL(fileURLWithPath: "/mock/echo_study.dcm")]
    model.files[.ct]             = [URL(fileURLWithPath: "/mock/ct_chest_001.dcm"), URL(fileURLWithPath: "/mock/ct_chest_002.dcm")]
    model.files[.coro]           = [URL(fileURLWithPath: "/mock/coro_left.dcm")]
    model.files[.other]          = []
    model.createdFolderURL       = URL(fileURLWithPath: "/mock/Patient Folder")
    model.status                 = "Folder created at /mock/Patient Folder"

    return ContentView(previewModel: model)
}
