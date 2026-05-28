//
//  TestFixtures.swift
//  DemoDICOMTests
//
//  Shared helpers for creating test data without touching the filesystem or real DICOM decoders.
//

import CoreGraphics
@testable import ATRIA

// MARK: - CGImage

/// Returns a minimal 1×1 CGImage suitable for seeding annotation sessions and viewer bundles.
func makeCGImage(width: Int = 1, height: Int = 1) -> CGImage {
    let bytesPerPixel = 4
    let ctx = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * bytesPerPixel,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    return ctx.makeImage()!
}

// MARK: - DICOMExamBundle

/// Returns a `DICOMExamBundle` pre-populated with `sliceCount` 1×1 dummy images.
/// Pass `includeRawBuffers: true` to attach a minimal 1×1 UInt16 buffer so that
/// `reapplyWindowing` passes its non-empty guard and actually starts processing.
func makeBundle(
    sliceCount: Int = 1,
    patientName: String = "Test Patient",
    seriesDescription: String = "Test Series",
    includeRawBuffers: Bool = false
) -> DICOMExamBundle {
    let images = (0..<sliceCount).map { _ in makeCGImage() }
    let rawBuffers: [([UInt16], Int, Int)] = includeRawBuffers
        ? [(Array(repeating: 2048, count: 1), 1, 1)]
        : []
    return DICOMExamBundle(
        sliceImages: images,
        rawPixelBuffers16: rawBuffers,
        currentSliceIndex: 0,
        patientName: patientName,
        studyDescription: "Test Study",
        seriesDescription: seriesDescription,
        modality: "CT"
    )
}
