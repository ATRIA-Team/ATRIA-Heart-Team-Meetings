//
//  TestFixtures.swift
//  DemoDICOMTests
//
//  Shared helpers for creating test data without touching the filesystem or real DICOM decoders.
//

import CoreGraphics
@testable import DemoDICOM

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
func makeBundle(
    sliceCount: Int = 1,
    patientName: String = "Test Patient",
    seriesDescription: String = "Test Series"
) -> DICOMExamBundle {
    let images = (0..<sliceCount).map { _ in makeCGImage() }
    return DICOMExamBundle(
        sliceImages: images,
        rawPixelBuffers16: [],
        currentSliceIndex: 0,
        patientName: patientName,
        studyDescription: "Test Study",
        seriesDescription: seriesDescription,
        modality: "CT"
    )
}
