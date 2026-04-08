import XCTest
@testable import DicomCore

final class LocalJPEG2000SmokeTests: XCTestCase {

    func testLocalSiemensJPEG2000CTASliceDecodesAs16Bit() throws {
        let folder = repoRoot()
            .appendingPathComponent("Specials 1CoronaryCTA_with_spiral _CTA_pre/Original/CorCTA w-c  3.0  B20f  0% - 9", isDirectory: true)

        guard FileManager.default.fileExists(atPath: folder.path) else {
            throw XCTSkip("Local JPEG2000 CTA sample folder not present")
        }

        let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension.lowercased() == "dcm" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        guard let sample = files.first else {
            throw XCTSkip("Local JPEG2000 CTA sample folder is empty")
        }

        let decoder = DCMDecoder()
        decoder.setDicomFilename(sample.path)

        let rawData = try Data(contentsOf: sample)
        let codestream = DCMPixelReader.extractEncapsulatedSingleFrame(
            data: rawData,
            offset: decoder.offset,
            numberOfFrames: decoder.nImages,
            transferSyntaxUID: DicomTransferSyntax.jpeg2000.rawValue
        )
        XCTAssertNotNil(codestream, "Expected encapsulated JPEG2000 codestream extraction to succeed")
        XCTAssertEqual(codestream?.prefix(4).map { String(format: "%02X", $0) }.joined(), "FF4FFF51")

        XCTAssertTrue(decoder.dicomFileReadSuccess, "Expected JPEG2000 sample to decode successfully")
        XCTAssertTrue(decoder.compressedImage, "Expected compressed transfer syntax")
        XCTAssertEqual(decoder.samplesPerPixel, 1, "Expected grayscale CT slice")
        XCTAssertEqual(decoder.bitDepth, 16, "Expected 16-bit output for CT slice")
        XCTAssertNotNil(decoder.getPixels16(), "Expected 16-bit pixels from JPEG2000 CTA slice")
    }

    func testLocalSiemensJPEG2000CTASeriesLoadsAsVolume() throws {
        let folder = repoRoot()
            .appendingPathComponent("Specials 1CoronaryCTA_with_spiral _CTA_pre/Original/CorCTA w-c  3.0  B20f  0% - 9", isDirectory: true)

        guard FileManager.default.fileExists(atPath: folder.path) else {
            throw XCTSkip("Local JPEG2000 CTA sample folder not present")
        }

        let loader = DicomSeriesLoader()
        let volume = try loader.loadSeries(in: folder)

        XCTAssertGreaterThan(volume.depth, 1, "Expected a multi-slice CTA series")
        XCTAssertGreaterThan(volume.width, 0)
        XCTAssertGreaterThan(volume.height, 0)
        XCTAssertFalse(volume.voxels.isEmpty, "Expected non-empty voxel buffer")
    }

    private func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // DicomCoreTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // DICOM-Decoder
            .deletingLastPathComponent()   // Packages
            .deletingLastPathComponent()   // Repo root
    }
}
