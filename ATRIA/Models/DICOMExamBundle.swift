//
//  DICOMExamBundle.swift
//  DemoDICOM
//

import CoreGraphics
import Foundation

// MARK: - DICOMExamBundle

/// An in-memory representation of a decoded DICOM exam: rendered slice images,
/// raw 16-bit pixel buffers for re-windowing, metadata, and playback state.
struct DICOMExamBundle {

    // MARK: - Identity

    let id: UUID

    // MARK: - Rendered images

    var sliceImages: [CGImage]

    // MARK: - Raw pixel data (kept for re-windowing without re-reading files)

    /// Parallel to `sliceImages`; each entry is (pixels16, width, height).
    var rawPixelBuffers16: [([UInt16], Int, Int)]

    // MARK: - Playback state

    var currentSliceIndex: Int

    // MARK: - DICOM metadata

    var patientName: String
    var studyDescription: String
    var seriesDescription: String
    var modality: String

    // MARK: - Convenience

    var sliceCount: Int { sliceImages.count }

    var currentSliceImage: CGImage? {
        guard !sliceImages.isEmpty, currentSliceIndex < sliceImages.count else { return nil }
        return sliceImages[currentSliceIndex]
    }

    // MARK: - Init

    init(
        id: UUID = UUID(),
        sliceImages: [CGImage] = [],
        rawPixelBuffers16: [([UInt16], Int, Int)] = [],
        currentSliceIndex: Int = 0,
        patientName: String = "",
        studyDescription: String = "",
        seriesDescription: String = "",
        modality: String = ""
    ) {
        self.id = id
        self.sliceImages = sliceImages
        self.rawPixelBuffers16 = rawPixelBuffers16
        self.currentSliceIndex = currentSliceIndex
        self.patientName = patientName
        self.studyDescription = studyDescription
        self.seriesDescription = seriesDescription
        self.modality = modality
    }
}
