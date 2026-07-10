//
//  SidePanel.swift
//  ATRIAmac
//

import SwiftUI

struct SidePanel: View {
    @Environment(FolderStore.self) private var store
    @Binding var folderName: String
    var onCreateTapped: () -> Void

    var body: some View {
        GlassCard(style: .panel, cornerRadius: 36) {
            VStack(spacing: 0) {
                Image(systemName: "folder.fill.badge.person.crop")
                    .font(.system(size: 46, weight: .semibold))
                    .padding(.top, 32)
                    .padding(.bottom, 10)

                Text("Package\nOrganizer")
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
                    Text("\(store.totalCount) file\(store.totalCount == 1 ? "" : "s") added")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let message = store.folderState.statusMessage {
                        Text(message)
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
                    Label("Create Package", systemImage: "folder.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .disabled(folderName.trimmingCharacters(in: .whitespaces).isEmpty || store.totalCount == 0)
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
