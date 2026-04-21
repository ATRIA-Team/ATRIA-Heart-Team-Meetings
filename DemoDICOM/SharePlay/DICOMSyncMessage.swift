//
//  DICOMSyncMessage.swift
//  DemoDICOM
//

import Foundation

/// A lightweight message exchanged between SharePlay participants.
///
/// Only control signals cross the wire — no DICOM pixel data is ever transmitted.
/// Pixel data always stays on each device's local storage.
struct DICOMSyncMessage: Codable {

    enum Kind: Codable {
        // MARK: - Viewing state (sent during active session)

        /// A participant scrolled to a new slice.
        case sliceChanged(index: Int)
        /// A participant changed the window/level preset.
        /// Uses the raw `Int` value of `MedicalPreset` for Codable compatibility.
        case presetChanged(rawValue: Int)

        // MARK: - Lobby readiness (sent during lobby phase)

        /// A participant has finished loading their local DICOM folder.
        case participantReady(sliceCount: Int, seriesDescription: String, patientName: String)
        /// A participant cleared their data or started a fresh import.
        case participantNotReady
        /// A participant (local or remote) cleared all 3D immersive drawings.
        case clearDrawings
        /// A participant removed a specific set of their own 2D annotation strokes
        /// from a specific session. Only the listed strokes are removed; others are preserved.
        case removeAnnotationStrokes(sessionID: UUID, strokeIDs: [UUID])

        // MARK: - Annotation Sessions

        /// A participant opened (or re-opened) an annotation window for the given session.
        /// `sliceIndex` tells receiving peers which slice to freeze as the session background.
        /// Receivers increment the session's open-count; if the session is unknown they create it.
        case annotationSessionOpened(sessionID: UUID, sliceIndex: Int)

        /// A participant closed their annotation window for the given session.
        /// Receivers decrement the session's open-count and remove it when it reaches zero.
        case annotationSessionClosed(sessionID: UUID)

        // MARK: - Drawing Space

        /// A participant opened the immersive drawing space.
        case drawingSpaceOpened
        /// A participant closed the immersive drawing space.
        case drawingSpaceClosed
    }

    let kind: Kind
}
