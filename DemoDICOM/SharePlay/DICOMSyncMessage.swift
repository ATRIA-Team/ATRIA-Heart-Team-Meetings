//
//  DICOMSyncMessage.swift
//  DemoDICOM
//

import Foundation

// MARK: - ExamType

/// All exam types a participant can load for a collaborative session.
enum ExamType: String, Codable, CaseIterable, Hashable {
    case medicalHistory
    case vitals
    case bloodTests
    case echo
    case ct
    case coro
    case other

    /// Exam types every participant must load before the session can start.
    /// Adjust this set to relax or tighten the readiness requirement.
    static var allRequired: Set<ExamType> { [.medicalHistory] }

    /// Human-readable label used in the UI.
    var displayName: String {
        switch self {
        case .medicalHistory: return "Medical History"
        case .vitals:         return "Vitals"
        case .bloodTests:     return "Blood Tests"
        case .echo:           return "Echo"
        case .ct:             return "CT"
        case .coro:           return "Coro"
        case .other:          return "Other"
        }
    }
}

// MARK: - ExamMetadata

/// Lightweight lobby metadata for one loaded exam — never contains pixel data or file contents.
enum ExamMetadata: Codable {
    /// DICOM exam (echo, CT, coro): carries slice count and series info for the lobby UI.
    case dicom(sliceCount: Int, seriesDescription: String, patientName: String)
    /// Document exam (medical history, vitals, blood tests, other): carries the file name.
    case document(fileName: String)
}

// MARK: - DICOMSyncMessage

/// A lightweight message exchanged between SharePlay participants.
///
/// Only control signals cross the wire — no pixel data or file contents are ever transmitted.
/// Each participant loads their own local copy of every exam file.
struct DICOMSyncMessage: Codable {

    enum Kind: Codable {
        // MARK: - Viewing state (sent during active session)

        /// A participant scrolled to a new slice.
        case sliceChanged(index: Int)
        /// A participant changed the window/level preset.
        case presetChanged(rawValue: Int)

        // MARK: - Lobby readiness

        /// A participant finished loading one exam type.
        case examReady(type: ExamType, metadata: ExamMetadata)
        /// A participant cleared or re-started loading one exam type.
        case examNotReady(type: ExamType)
        /// A participant manually started the session from the lobby button.
        case sessionStarted

        /// A participant cleared all 3D immersive drawings.
        case clearDrawings
        /// A participant removed specific 2D annotation strokes from a session.
        case removeAnnotationStrokes(sessionID: UUID, strokeIDs: [UUID])

        // MARK: - Annotation Sessions

        case annotationSessionOpened(sessionID: UUID, sliceIndex: Int)
        case annotationSessionClosed(sessionID: UUID)

        // MARK: - Drawing Space

        case drawingSpaceOpened
        case drawingSpaceClosed

        // MARK: - Shared Window

        /// A participant pushed an exam type into the shared window (nil = cleared).
        case sharedWindowChanged(examType: ExamType?)

        /// A participant pushed an annotation session into the shared window (nil = cleared).
        case sharedAnnotationChanged(sessionID: UUID?)
    }

    let kind: Kind
}
