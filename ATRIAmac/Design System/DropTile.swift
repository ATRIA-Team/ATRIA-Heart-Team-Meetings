//
//  DropTile.swift
//  ATRIAmac
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct DropTile: View {
    let category: Category
    @Environment(FolderStore.self) private var store
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

                let items = store.files[category] ?? []
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
                        Button { store.remove(url, from: category) } label: {
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
        Task { @MainActor in
            let urls = await withTaskGroup(of: URL?.self) { group in
                for provider in providers {
                    group.addTask {
                        await withCheckedContinuation { continuation in
                            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                                continuation.resume(returning: url)
                            }
                        }
                    }
                }
                return await group.reduce(into: [URL]()) { if let url = $1 { $0.append(url) } }
            }
            store.add(urls, to: category)
        }
        return true
    }
}
