//
//  ContentView.swift
//  DemoDICOMmac
//
//  Created by Igor Tarantino on 08/05/2026.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
internal import Combine

// MARK: - Model

enum Category: String, CaseIterable, Identifiable {
    case medicalHistory = "Medical History"
    case vitals         = "Vitals"
    case bloodTests     = "Blood Tests"
    case echo           = "Echo"
    case ct             = "CT"
    case coro           = "Coro"
    case other          = "Other"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .medicalHistory: return "list.bullet.clipboard.fill"
        case .vitals:         return "stethoscope"
        case .bloodTests:     return "drop.fill"
        case .echo:           return "waveform.path.ecg.text.clipboard.fill"
        case .ct:             return "waveform.path.ecg.rectangle.fill"
        case .coro:           return "heart.fill"
        case .other:          return "heart.text.clipboard.fill"
        }
    }
}

@MainActor
final class FolderModel: ObservableObject {
    @Published var files: [Category: [URL]] = Dictionary(
        uniqueKeysWithValues: Category.allCases.map { ($0, [URL]()) }
    )
    @Published var createdFolderURL: URL?
    @Published var status: String?

    var totalCount: Int { files.values.reduce(0) { $0 + $1.count } }

    func add(_ urls: [URL], to category: Category) {
        var current = files[category] ?? []
        for u in urls where !current.contains(u) { current.append(u) }
        files[category] = current
    }

    func remove(_ url: URL, from category: Category) {
        files[category]?.removeAll { $0 == url }
    }

    func createFolder(named name: String, in parent: URL) {
        let root = parent.appendingPathComponent(name, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            for category in Category.allCases {
                let sub = root.appendingPathComponent(category.rawValue, isDirectory: true)
                try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
                for src in files[category] ?? [] {
                    let dst = sub.appendingPathComponent(src.lastPathComponent)
                    if FileManager.default.fileExists(atPath: dst.path) {
                        try? FileManager.default.removeItem(at: dst)
                    }
                    try FileManager.default.copyItem(at: src, to: dst)
                }
            }
            createdFolderURL = root
            status = "Folder created at \(root.path)"
        } catch {
            status = "Error: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func moveToICloud() -> URL? {
        guard let src = createdFolderURL else { return nil }
        guard let iCloudRoot = iCloudDocumentsURL() else {
            status = "iCloud Drive not available."
            return nil
        }
        do {
            try FileManager.default.createDirectory(at: iCloudRoot, withIntermediateDirectories: true)
            let dst = iCloudRoot.appendingPathComponent(src.lastPathComponent, isDirectory: true)
            if FileManager.default.fileExists(atPath: dst.path) {
                try FileManager.default.removeItem(at: dst)
            }
            try FileManager.default.moveItem(at: src, to: dst)
            createdFolderURL = dst
            status = "Moved to iCloud Drive."
            return dst
        } catch {
            status = "iCloud move failed: \(error.localizedDescription)"
            return nil
        }
    }

    private func iCloudDocumentsURL() -> URL? {
        if let container = FileManager.default.url(forUbiquityContainerIdentifier: nil) {
            return container.appendingPathComponent("Documents")
        }
        let path = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
        return FileManager.default.fileExists(atPath: path.path) ? path : nil
    }
}

// MARK: - Root view

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

// MARK: - Side panel

struct SidePanel: View {
    @ObservedObject var model: FolderModel
    @Binding var folderName: String
    var onCreateTapped: () -> Void

    var body: some View {
        GlassCard(style: .panel, cornerRadius: 36) {
            VStack(spacing: 0) {
                Image(systemName: "folder.fill.badge.person.crop")
                    .font(.system(size: 46, weight: .semibold))
                    .padding(.top, 32)
                    .padding(.bottom, 10)

                Text("Folder\nOrganizer")
                    .font(.system(size: 20, weight: .bold))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 24)

                Divider().padding(.horizontal, 20).padding(.bottom, 20)

                VStack(alignment: .leading, spacing: 6) {
                    Text("FOLDER NAME")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .tracking(1)
                    TextField("Patient Folder", text: $folderName)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal, 20)

                Spacer()

                VStack(spacing: 4) {
                    Text("\(model.totalCount) file\(model.totalCount == 1 ? "" : "s") added")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let status = model.status {
                        Text(status)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .padding(.horizontal, 12)
                    }
                }
                .padding(.bottom, 12)

                Button {
                    onCreateTapped()
                } label: {
                    Label("Create Folder", systemImage: "folder.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .disabled(folderName.trimmingCharacters(in: .whitespaces).isEmpty || model.totalCount == 0)
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
        }
        .frame(width: 290, height: 460)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Drop tile

struct DropTile: View {
    let category: Category
    @ObservedObject var model: FolderModel
    @State private var isTargeted = false
    @State private var isHovered = false

    var body: some View {
        GlassCard(cornerRadius: 20, isHighlighted: isTargeted, showHoverOverlay: isHovered || isTargeted) {
            VStack(spacing: 10) {
                Image(systemName: isTargeted ? "arrow.down.circle.fill" : category.icon)
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(isTargeted ? Color.accentColor : .primary)
                    .animation(.easeInOut(duration: 0.15), value: isTargeted)

                Text(category.rawValue)
                    .font(.headline)

                let items = model.files[category] ?? []
                if items.isEmpty {
                    Text("Drag files here")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                } else {
                    fileList(items)
                }
            }
            .padding(16)
        }
        .frame(width: 175, height: 230)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .onHover { isHovered = $0 }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted, perform: handleDrop)
    }

    private func fileList(_ items: [URL]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 3) {
                ForEach(items, id: \.self) { url in
                    HStack {
                        Image(systemName: "doc").foregroundStyle(.secondary)
                        Text(url.lastPathComponent)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Button { model.remove(url, from: category) } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .font(.caption)
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(maxHeight: 100)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var collected: [URL] = []
        let group = DispatchGroup()
        for p in providers {
            group.enter()
            _ = p.loadObject(ofClass: URL.self) { url, _ in
                if let url { collected.append(url) }
                group.leave()
            }
        }
        group.notify(queue: .main) { model.add(collected, to: category) }
        return true
    }
}

// MARK: - Share row

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
