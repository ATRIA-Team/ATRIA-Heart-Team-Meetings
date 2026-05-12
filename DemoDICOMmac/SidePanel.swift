//
//  SidePanel.swift
//  DemoDICOMmac
//

import SwiftUI

struct SidePanel: View {
    @ObservedObject var model: FolderModel
    @Binding var folderName: String
    var onCreateTapped: () -> Void

    @State private var emailInput = ""

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

                Divider().padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 14)

                VStack(alignment: .leading, spacing: 8) {
                    Text("COLLABORATORS")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .tracking(1)

                    HStack(spacing: 6) {
                        TextField("iCloud email address", text: $emailInput)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { addEmail() }
                        Button(action: addEmail) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 18))
                        }
                        .buttonStyle(.plain)
                        .disabled(!isValidEmail(emailInput))
                    }

                    if !model.collaboratorEmails.isEmpty {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(model.collaboratorEmails, id: \.self) { email in
                                    HStack(spacing: 6) {
                                        Image(systemName: "person.circle")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(email)
                                            .font(.caption)
                                            .lineLimit(1)
                                        Spacer()
                                        Button {
                                            model.collaboratorEmails.removeAll { $0 == email }
                                        } label: {
                                            Image(systemName: "xmark")
                                                .font(.system(size: 9, weight: .semibold))
                                                .foregroundStyle(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.secondary.opacity(0.12))
                                    )
                                }
                            }
                        }
                        .frame(maxHeight: 90)
                    }
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
        .frame(width: 290)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }

    private func addEmail() {
        let trimmed = emailInput.trimmingCharacters(in: .whitespaces).lowercased()
        guard isValidEmail(trimmed), !model.collaboratorEmails.contains(trimmed) else { return }
        model.collaboratorEmails.append(trimmed)
        emailInput = ""
    }

    private func isValidEmail(_ s: String) -> Bool {
        let parts = s.split(separator: "@")
        return parts.count == 2 && parts[0].count >= 1 && parts[1].contains(".")
    }
}
