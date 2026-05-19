//
//  DocumentStore.swift
//  DemoDICOM
//

import Foundation

// MARK: - DocumentStore

/// Owns all non-DICOM file URLs and shared-window presentation state.
/// Pure state container — all broadcasting is handled by the orchestration layer (AppStore).
@Observable
final class DocumentStore {

    // MARK: - Local file URLs

    var medicalHistoryURL: URL?
    var vitalsURL: URL?
    var bloodTestURL: URL?
    var otherFileURL: URL?
    var htmlFileURL: URL?
    var pdfFileURL: URL?

    // MARK: - Shared window state

    /// The exam type currently pushed to the shared window (nil = placeholder).
    private(set) var sharedWindowExamType: ExamType?

    /// Scroll and zoom state for the shared PDF document.
    private(set) var sharedPDFState: SharedPDFState?

    /// The annotation session currently pushed to the shared window (nil = exam-type view).
    private(set) var sharedAnnotationSessionID: UUID?

    // MARK: - Document URL setters

    func setMedicalHistory(_ url: URL?) { medicalHistoryURL = url }
    func setVitals(_ url: URL?)         { vitalsURL = url }
    func setBloodTests(_ url: URL?)     { bloodTestURL = url }
    func setOther(_ url: URL?)          { otherFileURL = url }

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

    // MARK: - Document URL for a given exam type

    func documentURL(for examType: ExamType) -> URL? {
        switch examType {
        case .medicalHistory: return medicalHistoryURL
        case .vitals:         return vitalsURL
        case .bloodTests:     return bloodTestURL
        case .other:          return otherFileURL
        default:              return nil
        }
    }
}
