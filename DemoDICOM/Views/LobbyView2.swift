//
//  LobbyView2.swift
//  DemoDICOM
//
//  Created by Igor Tarantino on 22/05/2026.
//

import SwiftUI

private struct CategoryInfo {
    let icon: String
    let name: String
}

private let lobbyCategories: [CategoryInfo] = [
    CategoryInfo(icon: "list.bullet.clipboard.fill", name: "Medical History"),
    CategoryInfo(icon: "stethoscope",                name: "Vitals"),
    CategoryInfo(icon: "drop.fill",                  name: "Blood Tests"),
    CategoryInfo(icon: "waveform.path.ecg.text.clipboard.fill", name: "Echo"),
    CategoryInfo(icon: "waveform.path.ecg.rectangle.fill",      name: "CT"),
    CategoryInfo(icon: "heart.fill",                 name: "Coro"),
    CategoryInfo(icon: "heart.text.clipboard.fill",  name: "Other")
]

struct LobbyView2: View {

    @State private var uploadedFiles: [String: [String]]

    init(uploadedFiles: [String: [String]] = [:]) {
        let defaults = Dictionary(uniqueKeysWithValues: lobbyCategories.map { ($0.name, [String]()) })
        self._uploadedFiles = State(initialValue: defaults.merging(uploadedFiles) { _, new in new })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                HStack {
                    Image("atrialogo1")
                        .resizable()
                        .frame(width: 100, height: 40)
                    Text("Pre - Lobby")
                        .font(.extraLargeTitle)
                    Spacer()
                }

                HStack {
                    Text("Upload files from ATRIA companion app")
                        .font(.title)
                    Spacer()
                }

                PreLobbyButton(icon: "drop", text: "Blood Tests", width: 350, height: 200) {

                }
                .padding(.bottom, 40)

                Text("Upload files manually")
                    .font(.title)

                ScrollView(.horizontal) {
                    HStack(spacing: 25) {
                        PreLobbyButton(icon: "list.bullet.clipboard.fill", text: "Medical History", width: 350, height: 200) {}
                        PreLobbyButton(icon: "stethoscope",                text: "Vitals",          width: 350, height: 200) {}
                        PreLobbyButton(icon: "drop.fill",                  text: "Blood Tests",     width: 350, height: 200) {}
                        PreLobbyButton(icon: "waveform.path.ecg.text.clipboard.fill", text: "Echo", width: 350, height: 200) {}
                        PreLobbyButton(icon: "waveform.path.ecg.rectangle.fill",      text: "CT",   width: 350, height: 200) {}
                        PreLobbyButton(icon: "heart.fill",                 text: "Coro",            width: 350, height: 200) {}
                        PreLobbyButton(icon: "heart.text.clipboard.fill",  text: "Other",           width: 350, height: 200) {}
                    }
                }

                FilesUploadedPanel(uploadedFiles: $uploadedFiles)

                Spacer()
            }
            .padding(50)
        }
    }
}

// MARK: - Files uploaded panel

private struct FilesUploadedPanel: View {
    @Binding var uploadedFiles: [String: [String]]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Files uploaded")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.bottom, 20)

            ForEach(lobbyCategories, id: \.name) { category in
                CategoryRow(
                    icon: category.icon,
                    name: category.name,
                    files: Binding(
                        get: { uploadedFiles[category.name] ?? [] },
                        set: { uploadedFiles[category.name] = $0 }
                    )
                )

                if category.name != lobbyCategories.last?.name {
                    Divider()
                        .padding(.vertical, 10)
                }
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.5, green: 0.5, blue: 0.5), in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .inset(by: 0.7)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.4), .white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.4
                )
        )
    }
}

// MARK: - Category row

private struct CategoryRow: View {
    let icon: String
    let name: String
    @Binding var files: [String]
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .frame(width: 22, alignment: .center)
                Text(name)
                    .fontWeight(.semibold)
                Spacer()
                if !files.isEmpty {
                    Text("\(files.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.semibold))
                        .animation(.easeInOut(duration: 0.2), value: isExpanded)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                guard !files.isEmpty else { return }
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            }

            if isExpanded && !files.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(files, id: \.self) { file in
                        FileRow(fileName: file) {
                            withAnimation { files.removeAll { $0 == file } }
                        }
                    }
                }
                .padding(.top, 6)
            }
        }
    }
}

// MARK: - File row

private struct FileRow: View {
    let fileName: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.fill")
                .padding(.leading, 30)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(fileName)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer()

            Button(action: onRemove) {
                Image(systemName: "x.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .frame(height: 28)
    }
}

#Preview(windowStyle: .automatic) {
    LobbyView2(uploadedFiles: [
        "Medical History": ["patient_history_2024.pdf", "surgery_notes_2023.pdf"],
        "Vitals":          ["vitals_admission.pdf"],
        "Blood Tests":     ["CBC_march_2024.dcm", "lipid_panel.dcm", "metabolic_panel.dcm"],
        "Echo":            ["echo_apical4ch.dcm", "echo_parasternal.dcm"],
        "CT":              [],
        "Coro":            ["coro_lad_stenosis.dcm"],
        "Other":           []
    ])
}
