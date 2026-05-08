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

enum Category: String, CaseIterable, Identifiable {
    case medical = "Medical data"
    case ct = "CT"
    case blood = "Blood exams"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .medical: return "doc.text.fill"
        case .ct: return "brain.head.profile"
        case .blood: return "drop.fill"
        }
    }
}

@MainActor
final class FolderModel: ObservableObject {
    @Published var files: [Category: [URL]] = [
        .medical: [], .ct: [], .blood: []
    ]
    @Published var createdFolderURL: URL?
    @Published var status: String?

    func add(_ urls: [URL], to category: Category) {
        var current = files[category] ?? []
        for u in urls where !current.contains(u) {
            current.append(u)
        }
        files[category] = current
    }

    func remove(_ url: URL, from category: Category) {
        files[category]?.removeAll { $0 == url }
    }

    var totalCount: Int { files.values.reduce(0) { $0 + $1.count } }

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

    /// Moves the created folder into iCloud Drive root. Returns the new URL.
    @discardableResult
    func moveToICloud() -> URL? {
        guard let src = createdFolderURL else { return nil }
        guard let iCloudRoot = FileManager.default.url(forUbiquityContainerIdentifier: nil)?
                .appendingPathComponent("Documents")
              ?? defaultICloudDriveURL() else {
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

    private func defaultICloudDriveURL() -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let path = home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
        return FileManager.default.fileExists(atPath: path.path) ? path : nil
    }
}

struct ContentView: View {
    @StateObject private var model = FolderModel()
    @State private var folderName: String = "Patient Folder"

    var body: some View {
        VStack(spacing: 16) {
            Text("Cloud Folder Organizer")
                .font(.largeTitle.bold())

            HStack(spacing: 16) {
                ForEach(Category.allCases) { category in
                    DropCard(category: category, model: model)
                }
            }

            Divider()

            HStack {
                TextField("Folder name", text: $folderName)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 240)
                Button {
                    chooseLocationAndCreate()
                } label: {
                    Label("Create folder", systemImage: "folder.badge.plus")
                }
                .disabled(folderName.trimmingCharacters(in: .whitespaces).isEmpty || model.totalCount == 0)
                .keyboardShortcut(.defaultAction)
                Spacer()
            }

            if let url = model.createdFolderURL {
                ShareSection(folderURL: url, model: model)
            }

            if let status = model.status {
                Text(status)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(minWidth: 820, minHeight: 560)
    }

    private func chooseLocationAndCreate() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.message = "Choose where to create the folder"
        panel.directoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        if panel.runModal() == .OK, let parent = panel.url {
            model.createFolder(named: folderName, in: parent)
        }
    }
}

struct DropCard: View {
    let category: Category
    @ObservedObject var model: FolderModel
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: category.icon)
                .font(.system(size: 32))
                .foregroundStyle(.tint)
            Text(category.rawValue)
                .font(.headline)
            Text("Drag files here")
                .font(.caption)
                .foregroundStyle(.secondary)

            let items = model.files[category] ?? []
            if items.isEmpty {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundStyle(.secondary.opacity(0.4))
                    .frame(height: 120)
                    .overlay(Text("No files").foregroundStyle(.tertiary))
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(items, id: \.self) { url in
                            HStack {
                                Image(systemName: "doc")
                                Text(url.lastPathComponent)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                                Button {
                                    model.remove(url, from: category)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .font(.caption)
                        }
                    }
                    .padding(6)
                }
                .frame(height: 120)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.08)))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isTargeted ? Color.accentColor : Color.secondary.opacity(0.25),
                        lineWidth: isTargeted ? 2 : 1)
        )
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
            return true
        }
    }

    private func handleDrop(providers: [NSItemProvider]) {
        var collected: [URL] = []
        let group = DispatchGroup()
        for p in providers {
            group.enter()
            _ = p.loadObject(ofClass: URL.self) { url, _ in
                if let url { collected.append(url) }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            model.add(collected, to: category)
        }
    }
}

struct ShareSection: View {
    let folderURL: URL
    @ObservedObject var model: FolderModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Share folder")
                .font(.headline)
            Text("Move the folder to iCloud Drive and open the native share sheet to invite collaborators (Mail, Messages, Add People, Copy Link…).")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                NativeShareButton(items: [model.createdFolderURL ?? folderURL]) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }

                Button {
                    if let moved = model.moveToICloud() {
                        // Anchor a fresh picker on the same window after move
                        presentSharePicker(for: moved)
                    }
                } label: {
                    Label("Move to iCloud & Share", systemImage: "icloud.and.arrow.up")
                }

                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([model.createdFolderURL ?? folderURL])
                } label: {
                    Label("Reveal in Finder", systemImage: "folder")
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.08)))
    }

    private func presentSharePicker(for url: URL) {
        let picker = NSSharingServicePicker(items: [url])
        guard let window = NSApp.keyWindow, let view = window.contentView else { return }
        let rect = NSRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
        picker.show(relativeTo: rect, of: view, preferredEdge: .minY)
    }
}

/// A SwiftUI button that opens the native macOS share sheet anchored to itself.
struct NativeShareButton<Label: View>: View {
    let items: [Any]
    @ViewBuilder var label: () -> Label
    @State private var anchor: NSView?

    var body: some View {
        Button {
            guard let anchor else { return }
            let picker = NSSharingServicePicker(items: items)
            picker.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .minY)
        } label: {
            label()
        }
        .background(AnchorCapture(view: $anchor))
    }
}

private struct AnchorCapture: NSViewRepresentable {
    @Binding var view: NSView?

    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        DispatchQueue.main.async { self.view = v }
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

#Preview {
    ContentView()
}
