//
//  DocumentStore.swift
//  DemoDICOM
//

import Foundation

// MARK: - DocumentStore

/// Owns all non-DICOM file URLs and shared-window presentation state.
/// Each document category can hold multiple uploaded files.
/// Pure state container — all broadcasting is handled by the orchestration layer (AppStore).
@Observable
final class DocumentStore {

    // MARK: - Local file URL lists (one array per document category)

    private(set) var medicalHistoryURLs: [URL] = []
    private(set) var vitalsURLs: [URL] = []
    private(set) var bloodTestURLs: [URL] = []
    private(set) var otherFileURLs: [URL] = []

    // MARK: - Active document selection (which file is shown in the shared window per category)

    /// Tracks the user-chosen URL for each document category.
    /// Falls back to the first URL in the list when not explicitly set.
    private var activeDocumentURLs: [ExamType: URL] = [:]


    // MARK: - Shared window state

    /// The exam type currently pushed to the shared window (nil = placeholder).
    private(set) var sharedWindowExamType: ExamType?

    /// Scroll and zoom state for the shared PDF document.
    private(set) var sharedPDFState: SharedPDFState?

    /// The annotation session currently pushed to the shared window (nil = exam-type view).
    private(set) var sharedAnnotationSessionID: UUID?

    // MARK: - Document URL mutations

    func addMedicalHistory(_ url: URL) {
        guard !medicalHistoryURLs.contains(url) else { return }
        medicalHistoryURLs.append(url)
    }

    func removeMedicalHistory(_ url: URL) {
        medicalHistoryURLs.removeAll { $0 == url }
        if activeDocumentURLs[.medicalHistory] == url { activeDocumentURLs[.medicalHistory] = nil }
    }

    func addVitals(_ url: URL) {
        guard !vitalsURLs.contains(url) else { return }
        vitalsURLs.append(url)
    }

    func removeVitals(_ url: URL) {
        vitalsURLs.removeAll { $0 == url }
        if activeDocumentURLs[.vitals] == url { activeDocumentURLs[.vitals] = nil }
    }

    func addBloodTests(_ url: URL) {
        guard !bloodTestURLs.contains(url) else { return }
        bloodTestURLs.append(url)
    }

    func removeBloodTests(_ url: URL) {
        bloodTestURLs.removeAll { $0 == url }
        if activeDocumentURLs[.bloodTests] == url { activeDocumentURLs[.bloodTests] = nil }
    }

    func addOther(_ url: URL) {
        guard !otherFileURLs.contains(url) else { return }
        otherFileURLs.append(url)
    }

    func removeOther(_ url: URL) {
        otherFileURLs.removeAll { $0 == url }
        if activeDocumentURLs[.other] == url { activeDocumentURLs[.other] = nil }
    }

    // MARK: - Active document URL (for shared window display)

    /// Records which specific file the user chose to display for a given category.
    func setActiveDocumentURL(_ url: URL, examType: ExamType) {
        activeDocumentURLs[examType] = url
    }

    // MARK: - Document URL queries

    /// All uploaded URLs for a given document exam type.
    func documentURLs(for examType: ExamType) -> [URL] {
        switch examType {
        case .medicalHistory: return medicalHistoryURLs
        case .vitals:         return vitalsURLs
        case .bloodTests:     return bloodTestURLs
        case .other:          return otherFileURLs
        default:              return []
        }
    }

    /// The active (or first) URL for a given document exam type.
    /// Used by SharedWindow to know which file to display inline.
    func documentURL(for examType: ExamType) -> URL? {
        activeDocumentURLs[examType] ?? documentURLs(for: examType).first
    }

    // MARK: - Shared window mutations (called by AppStore after broadcasting)

    func applySharedWindow(_ examType: ExamType?) {
        sharedWindowExamType = examType
        if examType == nil { sharedPDFState = nil }
    }

    func applySharedAnnotation(_ sessionID: UUID?) {
        sharedAnnotationSessionID = sessionID
    }

    func applyRemotePDFState(_ state: SharedPDFState) {
        sharedPDFState = state
    }

    func setLocalPDFState(_ state: SharedPDFState?) {
        sharedPDFState = state
    }
}
