//
//  LobbyView.swift
//  DemoDICOM
//
//  Created by Igor Tarantino on 22/05/2026.
//

import SwiftUI
import GroupActivities
import UniformTypeIdentifiers
import _GroupActivities_UIKit

// MARK: - Category metadata

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

// MARK: - File item model

private struct FileItem: Identifiable {
    let id = UUID()
    let name: String
    let removeAction: () -> Void
}

// MARK: - LobbyView

struct LobbyView: View {
    
    @Environment(AppStore.self) private var store
    
    private enum ActivePicker {
        case atriaPackage
        case medicalHistory, vitals, bloodTests, other
        case echo, ct, coro
        
        var allowedTypes: [UTType] {
            switch self {
            case .atriaPackage:
                return [.atriaPackage]
            case .medicalHistory, .vitals, .bloodTests, .other:
                return [.pdf, .image]
            case .echo, .ct, .coro:
                return [.folder]
            }
        }
    }
    
    @State private var activePicker: ActivePicker? = nil
    @State private var isPickerPresented = false
    
    // MARK: - Atria button state
    
    private var atriaButtonState: AtriaPackageButtonState {
        guard store.iCloud.hasFolder else { return .waiting }
        let readyCounts = store.session.participantStates.values
            .filter { $0.isReady }
            .map { $0.sliceCount }
        guard readyCounts.count >= 2 else { return .uploaded }
        return Set(readyCounts).count > 1 ? .mismatch : .uploaded
    }
    
    // MARK: - Computed file items from store
    
    private func fileItems(for category: String) -> [FileItem] {
        switch category {
        case "Medical History":
            return store.document.medicalHistoryURLs.map { url in
                FileItem(name: url.lastPathComponent) { store.removeMedicalHistory(url) }
            }
        case "Vitals":
            return store.document.vitalsURLs.map { url in
                FileItem(name: url.lastPathComponent) { store.removeVitals(url) }
            }
        case "Blood Tests":
            return store.document.bloodTestURLs.map { url in
                FileItem(name: url.lastPathComponent) { store.removeBloodTests(url) }
            }
        case "Other":
            return store.document.otherFileURLs.map { url in
                FileItem(name: url.lastPathComponent) { store.removeOther(url) }
            }
        case "Echo":
            return (store.viewer.dicomExams[.echo] ?? []).map { bundle in
                let displayName = bundle.seriesDescription.isEmpty
                ? "Echo · \(bundle.sliceCount) slices"
                : "\(bundle.seriesDescription) · \(bundle.sliceCount) slices"
                let bundleID = bundle.id
                return FileItem(name: displayName) { store.removeBundle(id: bundleID, examType: .echo) }
            }
        case "CT":
            return (store.viewer.dicomExams[.ct] ?? []).map { bundle in
                let displayName = bundle.seriesDescription.isEmpty
                ? "CT · \(bundle.sliceCount) slices"
                : "\(bundle.seriesDescription) · \(bundle.sliceCount) slices"
                let bundleID = bundle.id
                return FileItem(name: displayName) { store.removeBundle(id: bundleID, examType: .ct) }
            }
        case "Coro":
            return (store.viewer.dicomExams[.coro] ?? []).map { bundle in
                let displayName = bundle.seriesDescription.isEmpty
                ? "Coro · \(bundle.sliceCount) slices"
                : "\(bundle.seriesDescription) · \(bundle.sliceCount) slices"
                let bundleID = bundle.id
                return FileItem(name: displayName) { store.removeBundle(id: bundleID, examType: .coro) }
            }
        default:
            return []
        }
    }
    
    // MARK: - Body
    
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
                
                HStack {
                    
                    AtriaPackageButton(state: atriaButtonState) {
                        activePicker = .atriaPackage
                        isPickerPresented = true
                    }
                    .padding(.bottom, 40)
                    
                    Button {
                        store.iCloud.loadAllFiles(into: store)
                    } label: {
                        Image(systemName: "arrow.trianglehead.2.clockwise")
                            .font(.system(size: 25))
                    }
                    .buttonBorderShape(.circle)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.4), .white.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.4
                            )
                    )
                    .padding(.leading, 10)
                    .padding(.top, 110)
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        
                        Text("Start meeting after uploading all the necessary files")
                            .font(.largeTitle)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 300)
                        
                        Button {
                            store.session.startSession()
                        } label: {
                            Text("Start")
                                .font(.system(size: 25, weight: .bold))
                                .frame(width: 150, height: 15)
                                .padding()
                        }
                        .background(LinearGradient(colors: [Color.black.opacity(0.3), Color.black.opacity(0.1)], startPoint: .bottom, endPoint: .top))
                        .clipShape(Capsule())
                        .buttonStyle(.plain)
                        .glassBackgroundEffect()
                        .padding(.trailing, 25)
                    }
                }
                
                Text("Upload files manually")
                    .font(.title)
                
                ScrollView(.horizontal) {
                    HStack(spacing: 25) {
                        PreLobbyButton(icon: "list.bullet.clipboard.fill", text: "Medical History", width: 350, height: 200) {
                            activePicker = .medicalHistory
                            isPickerPresented = true
                        }
                        PreLobbyButton(icon: "stethoscope", text: "Vitals", width: 350, height: 200) {
                            activePicker = .vitals
                            isPickerPresented = true
                        }
                        PreLobbyButton(icon: "drop.fill", text: "Blood Tests", width: 350, height: 200) {
                            activePicker = .bloodTests
                            isPickerPresented = true
                        }
                        PreLobbyButton(icon: "waveform.path.ecg.text.clipboard.fill", text: "Echo", width: 350, height: 200) {
                            activePicker = .echo
                            isPickerPresented = true
                        }
                        PreLobbyButton(icon: "waveform.path.ecg.rectangle.fill", text: "CT", width: 350, height: 200) {
                            activePicker = .ct
                            isPickerPresented = true
                        }
                        PreLobbyButton(icon: "heart.fill", text: "Coro", width: 350, height: 200) {
                            activePicker = .coro
                            isPickerPresented = true
                        }
                        PreLobbyButton(icon: "heart.text.clipboard.fill", text: "Other", width: 350, height: 200) {
                            activePicker = .other
                            isPickerPresented = true
                        }
                    }
                }
                
                FilesUploadedPanel(fileItems: fileItems)
                
                Spacer()
            }
            .padding(50)
        }
        .fileImporter(
            isPresented: $isPickerPresented,
            allowedContentTypes: activePicker?.allowedTypes ?? [.folder],
            allowsMultipleSelection: false
        ) { result in
            defer { activePicker = nil }
            guard case .success(let urls) = result, let url = urls.first else { return }
            switch activePicker {
            case .atriaPackage:   store.iCloud.openAtriaPackage(url, into: store)
            case .medicalHistory: store.addMedicalHistory(url)
            case .vitals:         store.addVitals(url)
            case .bloodTests:     store.addBloodTests(url)
            case .other:          store.addOther(url)
            case .echo:           store.importFolder(url: url, examType: .echo)
            case .ct:             store.importFolder(url: url, examType: .ct)
            case .coro:           store.importFolder(url: url, examType: .coro)
            case nil:             break
            }
        }
        .overlay {
            if store.viewer.isLoading { loadingOverlay }
        }
        .alert(
            "Error",
            isPresented: Binding(
                get: { store.viewer.errorMessage != nil },
                set: { if !$0 { store.viewer.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.viewer.errorMessage ?? "")
        }
    }
    
    // MARK: - Loading overlay
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView().scaleEffect(1.5)
                Text("Loading DICOM slices…").font(.headline)
            }
            .padding(32)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        }
    }
}

// MARK: - Files uploaded panel

private struct FilesUploadedPanel: View {
    let fileItems: (String) -> [FileItem]
    
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
                    files: fileItems(category.name)
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
    let files: [FileItem]
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
                    ForEach(files) { file in
                        FileRow(fileName: file.name, onRemove: file.removeAction)
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

// MARK: - GroupActivitySharingSheet

private struct GroupActivitySharingSheet<Activity: GroupActivity>: UIViewControllerRepresentable {
    let activity: Activity
    
    func makeUIViewController(context: Context) -> UIViewController {
        (try? GroupActivitySharingController(activity)) ?? UIViewController()
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

#Preview(windowStyle: .automatic) {
    LobbyView()
        .environment(AppStore())
}
