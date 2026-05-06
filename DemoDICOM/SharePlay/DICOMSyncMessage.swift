//
//  DICOMSyncMessage.swift
//  DemoDICOM
//

import Foundation

// MARK: - ExamType

/// The set of exam types participants can load for a collaborative session.
enum ExamType: String, Codable, CaseIterable, Hashable {
    case dicom
    case bloodTests
    case medicalRecord

    /// Every exam type every participant must have loaded before the session can start.
    static var allRequired: Set<ExamType> { Set(ExamType.allCases) }
}

// MARK: - ExamMetadata

/// Lightweight lobby metadata for one loaded exam — never contains pixel data or file contents.
enum ExamMetadata: Codable {
    case dicom(sliceCount: Int, seriesDescription: String, patientName: String)
    case bloodTests(fileName: String)
    case medicalRecord(fileName: String)
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
        /// Uses the raw `Int` value of `MedicalPreset` for Codable compatibility.
        case presetChanged(rawValue: Int)

        // MARK: - Lobby readiness (sent during lobby phase)

        /// A participant finished loading one exam type.
        case examReady(type: ExamType, metadata: ExamMetadata)
        /// A participant cleared or re-started loading one exam type.
        case examNotReady(type: ExamType)

        /// A participant (local or remote) cleared all 3D immersive drawings.
        case clearDrawings
        /// A participant removed a specific set of their own 2D annotation strokes
        /// from a specific session. Only the listed strokes are removed; others are preserved.
        case removeAnnotationStrokes(sessionID: UUID, strokeIDs: [UUID])

        // MARK: - Annotation Sessions

        /// A participant opened (or re-opened) an annotation window for the given session.
        case annotationSessionOpened(sessionID: UUID, sliceIndex: Int)
        /// A participant closed their annotation window for the given session.
        case annotationSessionClosed(sessionID: UUID)

        // MARK: - Drawing Space

        /// A participant opened the immersive drawing space.
        case drawingSpaceOpened
        /// A participant closed the immersive drawing space.
        case drawingSpaceClosed
    }

    let kind: Kind
}
