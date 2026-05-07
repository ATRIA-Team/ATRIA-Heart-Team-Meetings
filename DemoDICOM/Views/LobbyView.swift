//
//  LobbyView.swift
//  DemoDICOM
//

import SwiftUI
import UniformTypeIdentifiers

/// Pre-session lobby shown while a SharePlay session is active but not all
/// participants have loaded their local DICOM folder yet.
///
/// Each participant imports their own copy of every exam file. When the last participant
/// marks themselves ready, `SharePlayCoordinator.sessionHasStarted` latches to
/// `true` and `RootView` automatically transitions everyone to the viewer.
struct LobbyView: View {

    @Environment(DICOMStore.self) private var store

    private enum ActivePicker {
        case echo, ct, coro, medicalHistory, vitals, bloodTests, other
        var allowedTypes: [UTType] {
            switch self {
            case .echo, .ct, .coro: return [.folder]
            case .medicalHistory, .bloodTests, .vitals, .other: return [.pdf, .image]
            }
        }
    }
    @State private var activePicker: ActivePicker? = nil
    @State private var isPickerPresented = false

    var body: some View {
        @Bindable var store = store

        ScrollView {
            VStack(spacing: 28) {
                headerSection
                participantsSection
                if hasMismatchWarning { mismatchBanner }
                importSection
                if !uploadedFileEntries.isEmpty { uploadedFilesSection }
            }
            .padding(24)
        }
        .navigationTitle("Session lobby")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Label(
                    "\(store.sharePlay.participantCount) connected",
                    systemImage: "shareplay"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
        .fileImporter(
            isPresented: $isPickerPresented,
            allowedContentTypes: activePicker?.allowedTypes ?? [.folder],
            allowsMultipleSelection: false
        ) { result in
            defer { activePicker = nil }
            guard case .success(let urls) = result, let url = urls.first else { return }
            switch activePicker {
            case .echo:           store.importFolder(url: url, examType: .echo)
            case .ct:             store.importFolder(url: url, examType: .ct)
            case .coro:           store.importFolder(url: url, examType: .coro)
            case .medicalHistory: store.medicalHistoryURL = url; store.broadcastDocumentChange(.medicalHistory, url: url)
            case .vitals:         store.vitalsURL = url;         store.broadcastDocumentChange(.vitals,         url: url)
            case .bloodTests:     store.bloodTestURL = url;      store.broadcastDocumentChange(.bloodTests,     url: url)
            case .other:          store.otherFileURL = url;      store.broadcastDocumentChange(.other,          url: url)
            case nil:             break
            }
        }
        .overlay {
            if store.isLoading { loadingOverlay }
        }
        .alert(
            "Error",
            isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { if !$0 { store.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 14) {
            Image(systemName: "person.2.wave.2.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
                .symbolEffect(.pulse)

            Text("Collaborative session")
                .font(.title2.weight(.semibold))

            Text("Each participant loads their own local copy of every exam file. The session can be started when all participants uploaded at least the medical record of the patient.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    // MARK: - Participants

    private var sortedParticipants: [ParticipantReadyState] {
        store.sharePlay.participantStates.values
            .sorted { $0.isLocal && !$1.isLocal }
    }

    private var participantsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label("Participants", systemImage: "person.2.fill")
                .font(.headline)
                .padding(.bottom, 14)

            if sortedParticipants.isEmpty {
                Text("Waiting for participants to join…")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 0) {
                    ForEach(sortedParticipants) { state in
                        ParticipantRow(state: state)
                        if state.id != sortedParticipants.last?.id {
                            Divider().padding(.leading, 44)
                        }
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Mismatch warning

    private var hasMismatchWarning: Bool {
        let readyCounts = store.sharePlay.participantStates.values
            .filter { $0.isReady }
            .map { $0.sliceCount }
        guard readyCounts.count >= 2 else { return false }
        return Set(readyCounts).count > 1
    }

    private var mismatchBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text("Slice count mismatch")
                    .font(.subheadline.weight(.semibold))
                Text("Participants have loaded different numbers of slices. Verify that everyone is using the same DICOM series before proceeding.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.yellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.yellow.opacity(0.35), lineWidth: 1)
        )
    }

    // MARK: - Uploaded files

    private struct FileEntry: Identifiable {
        let id = UUID()
        let icon: String
        let tint: Color
        let label: String
        let detail: String
    }

    private var uploadedFileEntries: [FileEntry] {
        var entries: [FileEntry] = []
        let dicomTypes: [(ExamType, String, String)] = [
            (.echo,  "waveform.path.ecg.text.clipboard.fill", "Echo"),
            (.ct,    "waveform.path.ecg.rectangle.fill",      "CT Scan"),
            (.coro,  "heart.fill",                            "Coronary"),
        ]
        for (examType, icon, label) in dicomTypes {
            if let bundle = store.dicomExams[examType], bundle.sliceCount > 0 {
                entries.append(FileEntry(icon: icon, tint: .blue, label: label,
                                         detail: "\(bundle.sliceCount) slices"))
            }
        }
        let docTypes: [(URL?, String, String, Color)] = [
            (store.medicalHistoryURL, "list.bullet.clipboard.fill", "Medical History", .green),
            (store.vitalsURL,         "stethoscope",                "Vitals",          .orange),
            (store.bloodTestURL,      "drop.fill",                  "Blood Tests",     .red),
            (store.otherFileURL,      "heart.text.clipboard.fill",  "Other",           .purple),
        ]
        for (url, icon, label, tint) in docTypes {
            if let url {
                entries.append(FileEntry(icon: icon, tint: tint, label: label,
                                         detail: url.lastPathComponent))
            }
        }
        return entries
    }

    private var uploadedFilesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label("Loaded files", systemImage: "tray.full.fill")
                .font(.headline)
                .padding(.bottom, 14)

            VStack(spacing: 0) {
                ForEach(uploadedFileEntries) { entry in
                    HStack(spacing: 12) {
                        Image(systemName: entry.icon)
                            .foregroundStyle(entry.tint)
                            .font(.body)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.label)
                                .font(.subheadline.weight(.medium))
                            Text(entry.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.body)
                    }
                    .padding(.vertical, 10)

                    if entry.id != uploadedFileEntries.last?.id {
                        Divider().padding(.leading, 40)
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Import section

    private var localState: ParticipantReadyState? {
        store.sharePlay.participantStates.values.first { $0.isLocal }
    }

    private var waitingCount: Int {
        store.sharePlay.participantStates.values.filter { !$0.isReady }.count
    }

    @ViewBuilder
    private var importSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Upload exam files")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    examButton(.medicalHistory, icon: "list.bullet.clipboard.fill", text: "Medical History") { activePicker = .medicalHistory; isPickerPresented = true }
                    examButton(.vitals,         icon: "stethoscope",                text: "Vitals")          { activePicker = .vitals;         isPickerPresented = true }
                    examButton(.bloodTests,     icon: "drop.fill",                  text: "Blood Tests")     { activePicker = .bloodTests;     isPickerPresented = true }
                    examButton(.echo,           icon: "waveform.path.ecg.text.clipboard.fill", text: "Echo") { activePicker = .echo;           isPickerPresented = true }
                    examButton(.ct,   icon: "waveform.path.ecg.rectangle.fill", text: "CT")    { activePicker = .ct;   isPickerPresented = true }
                    examButton(.coro, icon: "heart.fill",                        text: "Coro")  { activePicker = .coro; isPickerPresented = true }
                    examButton(.other, icon: "heart.text.clipboard.fill",        text: "Other") { activePicker = .other; isPickerPresented = true }
                }
            }

            let loadedCount = localState?.loadedExams.count ?? 0
            Text("\(loadedCount) of \(ExamType.allCases.count) exam types uploaded")
                .font(.caption)
                .foregroundStyle(.secondary)

            let canStart = store.sharePlay.allParticipantsReady
            Button {
                store.sharePlay.startSession()
            } label: {
                Label("Start Session", systemImage: "play.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canStart)

            if !canStart {
                Text("Waiting for all participants to upload the required file…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    /// Exam button that shows a checkmark icon when that exam type is already loaded.
    @ViewBuilder
    private func examButton(_ examType: ExamType, icon: String, text: String, action: @escaping () -> Void) -> some View {
        let isLoaded = localState?.loadedExams.contains(examType) == true
        RemoteControlButton(
            icon: isLoaded ? "checkmark.circle.fill" : icon,
            text: text,
            action: action
        )
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

// MARK: - ParticipantRow

private struct ParticipantRow: View {
    let state: ParticipantReadyState

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if state.isReady {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title3)
                } else {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 22, height: 22)
                }
            }
            .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(state.isLocal ? "You" : "Participant")
                        .font(.subheadline.weight(.medium))
                    if state.isLocal {
                        Text("· This device")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                let loaded = state.loadedExams.count
                let total  = ExamType.allCases.count
                Text("\(loaded) / \(total) exams loaded")
                    .font(.caption)
                    .foregroundStyle(state.isReady ? .green : .secondary)
            }

            Spacer()
        }
        .padding(.vertical, 10)
    }
}
