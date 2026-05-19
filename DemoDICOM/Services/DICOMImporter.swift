//
//  DICOMImporter.swift
//  DemoDICOM
//

import CoreGraphics
import DicomCore

// MARK: - DICOMImporter

/// Pure service that reads a folder of DICOM files and returns a populated `DICOMExamBundle`.
/// Has no state and no side effects — safe to call from any async context.
///
/// Inject a mock conforming to `DICOMImporting` in tests to avoid touching the filesystem.
protocol DICOMImporting {
    func importFolder(url: URL, currentPreset: MedicalPreset) async throws -> DICOMExamBundle
}

struct DICOMImporter: DICOMImporting {

    enum ImportError: LocalizedError {
        case noFilesFound
        case allCompressed(count: Int)
        case partiallyCompressed(skipped: Int, total: Int)
        case noDecodableSlices

        var errorDescription: String? {
            switch self {
            case .noFilesFound:
                return "No DICOM files found in the selected folder. Make sure you selected the right folder."
            case .allCompressed(let count):
                return "All \(count) files use a compressed transfer syntax, but none could be decoded.\n\n" +
                       "Single-frame JPEG and JPEG2000 DICOM images are supported.\n\n" +
                       "Fallback: dcmconv --write-xfer-little input.dcm output.dcm"
            case .partiallyCompressed(let skipped, let total):
                return "\(skipped) of \(total) files used compressed transfer syntaxes and were skipped. No decodable slices remained."
            case .noDecodableSlices:
                return "Could not decode any DICOM slices from this folder."
            }
        }
    }

    func importFolder(url: URL, currentPreset: MedicalPreset) async throws -> DICOMExamBundle {
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(
            at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]
        )

        let dicomFiles = contents.filter { u in
            let isReg = (try? u.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) ?? true
            guard isReg else { return false }
            let ext = u.pathExtension.lowercased()
            return ext == "dcm" || ext == "dicom" || ext == "ima" || ext.isEmpty
        }.sorted { $0.lastPathComponent < $1.lastPathComponent }

        guard !dicomFiles.isEmpty else { throw ImportError.noFilesFound }

        struct SliceEntry {
            let instanceNumber: Int
            let pixels16: [UInt16]
            let width: Int
            let height: Int
        }

        var sliceEntries: [SliceEntry] = []
        var firstDecoder: DCMDecoder?
        var compressedCount = 0
        let totalCount = dicomFiles.count

        for fileURL in dicomFiles {
            let decoder = DCMDecoder()
            decoder.setDicomFilename(fileURL.path)
            guard decoder.dicomFileReadSuccess else { continue }
            if decoder.compressedImage { compressedCount += 1 }

            let pixels16: [UInt16]?
            if let p16 = decoder.getPixels16() {
                pixels16 = p16
            } else if let p8 = decoder.getPixels8() {
                pixels16 = p8.map { UInt16($0) << 8 }
            } else {
                continue
            }
            guard let pixels = pixels16 else { continue }
            if firstDecoder == nil { firstDecoder = decoder }

            let instanceNumber = decoder.intValue(for: 0x00200013) ?? sliceEntries.count
            sliceEntries.append(SliceEntry(instanceNumber: instanceNumber, pixels16: pixels, width: decoder.width, height: decoder.height))
        }

        if sliceEntries.isEmpty {
            if compressedCount == totalCount { throw ImportError.allCompressed(count: compressedCount) }
            if compressedCount > 0          { throw ImportError.partiallyCompressed(skipped: compressedCount, total: totalCount) }
            throw ImportError.noDecodableSlices
        }

        sliceEntries.sort { $0.instanceNumber < $1.instanceNumber }

        let patientInfo = firstDecoder?.getPatientInfo()  ?? [:]
        let studyInfo   = firstDecoder?.getStudyInfo()    ?? [:]
        let seriesInfo  = firstDecoder?.getSeriesInfo()   ?? [:]
        let modalityStr = firstDecoder?.info(for: 0x00080060) ?? ""

        let headerCenter = firstDecoder?.windowCenter ?? 0
        let headerWidth  = firstDecoder?.windowWidth  ?? 0

        let windowCenter: Double
        let windowWidth: Double
        if headerWidth > 0 {
            windowCenter = headerCenter
            windowWidth  = headerWidth
        } else if let optimal = firstDecoder?.calculateOptimalWindow() {
            windowCenter = optimal.center
            windowWidth  = optimal.width
        } else {
            let preset = DCMWindowingProcessor.getPresetValues(preset: currentPreset)
            windowCenter = preset.center
            windowWidth  = preset.width
        }

        var images: [CGImage] = []
        var rawBuffers: [([UInt16], Int, Int)] = []
        for entry in sliceEntries {
            rawBuffers.append((entry.pixels16, entry.width, entry.height))
            if let windowed = DCMWindowingProcessor.applyWindowLevel(pixels16: entry.pixels16, center: windowCenter, width: windowWidth),
               let cgImage  = CGImage.fromDICOMWindowedData(windowed, width: entry.width, height: entry.height) {
                images.append(cgImage)
            }
        }

        return DICOMExamBundle(
            sliceImages: images,
            rawPixelBuffers16: rawBuffers,
            currentSliceIndex: images.count / 2,
            patientName: patientInfo["Name"] ?? "",
            studyDescription: studyInfo["StudyDescription"] ?? "",
            seriesDescription: seriesInfo["SeriesDescription"] ?? "",
            modality: modalityStr
        )
    }
}
