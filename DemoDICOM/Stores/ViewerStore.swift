//
//  ViewerStore.swift
//  DemoDICOM
//

import CoreGraphics
import DicomCore

// MARK: - ViewerStore

/// Owns all DICOM viewer state: exam bundles, selected exam, windowing preset, and loading/error state.
/// Pure state container — import orchestration and SharePlay broadcasting are handled by AppStore.
@Observable
final class ViewerStore {

    // MARK: - DICOM exam storage

    /// Independent data bundle per exam type. Echo, CT, and Coro can all be loaded simultaneously.
    private(set) var dicomExams: [ExamType: DICOMExamBundle] = [:]

    /// The exam type currently shown in the viewer.
    var selectedDICOMExamType: ExamType?

    /// DICOM exam types that have been successfully loaded, in display order.
    var loadedDICOMExamTypes: [ExamType] {
        [.echo, .ct, .coro].filter { !(dicomExams[$0]?.sliceImages.isEmpty ?? true) }
    }

    // MARK: - Computed slice state

    var sliceImages: [CGImage] { selectedBundle?.sliceImages ?? [] }

    var currentSliceIndex: Int {
        get { selectedBundle?.currentSliceIndex ?? 0 }
        set {
            guard let examType = selectedDICOMExamType,
                  newValue != dicomExams[examType]?.currentSliceIndex else { return }
            dicomExams[examType]?.currentSliceIndex = newValue
        }
    }

    var patientName: String       { selectedBundle?.patientName       ?? "" }
    var studyDescription: String  { selectedBundle?.studyDescription  ?? "" }
    var seriesDescription: String { selectedBundle?.seriesDescription ?? "" }
    var modality: String          { selectedBundle?.modality          ?? "" }
    var sliceCount: Int           { selectedBundle?.sliceCount        ?? 0 }
    var currentSliceImage: CGImage? { selectedBundle?.currentSliceImage }

    private var selectedBundle: DICOMExamBundle? {
        guard let examType = selectedDICOMExamType else { return nil }
        return dicomExams[examType]
    }

    // MARK: - Window preset

    var selectedPreset: MedicalPreset = .softTissue

    // MARK: - Loading / error state

    private(set) var isLoading: Bool = false
    var errorMessage: String?

    // MARK: - Remote state application (called by AppStore when a SharePlay message arrives)

    func applyRemoteSliceChange(_ index: Int) {
        guard index >= 0, index < sliceCount,
              let examType = selectedDICOMExamType else { return }
        dicomExams[examType]?.currentSliceIndex = index
    }

    func applyRemotePresetChange(_ preset: MedicalPreset) {
        selectedPreset = preset
    }

    // MARK: - Exam management (called by AppStore)

    func prepareForImport(examType: ExamType) {
        dicomExams[examType] = DICOMExamBundle()
        selectedDICOMExamType = examType
        isLoading = true
        errorMessage = nil
    }

    func applyImportResult(_ bundle: DICOMExamBundle, examType: ExamType) {
        dicomExams[examType] = bundle
        selectedDICOMExamType = examType
        isLoading = false
    }

    func applyImportError(_ message: String) {
        errorMessage = message
        isLoading = false
    }

    func removeExam(_ examType: ExamType) {
        dicomExams[examType] = nil
        if selectedDICOMExamType == examType { selectedDICOMExamType = nil }
    }

    // MARK: - Windowing re-application

    /// Re-applies the current preset to the raw buffers of the selected exam.
    /// Calls `onComplete` on the MainActor when done.
    func reapplyWindowing(onComplete: @MainActor @escaping ([CGImage], ExamType) -> Void) {
        guard let examType = selectedDICOMExamType,
              let bundle = dicomExams[examType],
              !bundle.rawPixelBuffers16.isEmpty else { return }

        isLoading = true
        let preset = selectedPreset
        let buffers = bundle.rawPixelBuffers16

        Task.detached {
            let presetValues = DCMWindowingProcessor.getPresetValues(preset: preset)
            var images: [CGImage] = []
            for (pixels, width, height) in buffers {
                if let windowed = DCMWindowingProcessor.applyWindowLevel(pixels16: pixels, center: presetValues.center, width: presetValues.width),
                   let cgImage  = CGImage.fromDICOMWindowedData(windowed, width: width, height: height) {
                    images.append(cgImage)
                }
            }
            await onComplete(images, examType)
        }
    }

    func applyRewindowedImages(_ images: [CGImage], examType: ExamType) {
        dicomExams[examType]?.sliceImages = images
        if (dicomExams[examType]?.currentSliceIndex ?? 0) >= images.count {
            dicomExams[examType]?.currentSliceIndex = max(0, images.count - 1)
        }
        isLoading = false
    }
}
