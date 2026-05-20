//
//  ViewerStore.swift
//  DemoDICOM
//

import Foundation
import CoreGraphics
import DicomCore

// MARK: - ViewerStore

/// Owns all DICOM viewer state: exam bundles, selected exam, windowing preset, and loading/error state.
/// Each exam type can hold multiple bundles (one per imported folder).
/// Pure state container — import orchestration and SharePlay broadcasting are handled by AppStore.
@Observable
final class ViewerStore {

    // MARK: - DICOM exam storage

    /// All imported bundles per exam type. nil means no import has been done for that type.
    private(set) var dicomExams: [ExamType: [DICOMExamBundle]] = [:]

    /// Which bundle is currently selected within each exam type's array.
    private(set) var selectedBundleIndices: [ExamType: Int] = [:]

    /// The exam type currently shown in the viewer.
    var selectedDICOMExamType: ExamType?

    /// DICOM exam types that have at least one successfully loaded bundle, in display order.
    var loadedDICOMExamTypes: [ExamType] {
        [.echo, .ct, .coro].filter { !(dicomExams[$0]?.isEmpty ?? true) }
    }

    // MARK: - Computed slice state (always relative to the selected bundle)

    var sliceImages: [CGImage] { selectedBundle?.sliceImages ?? [] }

    var currentSliceIndex: Int {
        get { selectedBundle?.currentSliceIndex ?? 0 }
        set {
            guard let examType = selectedDICOMExamType else { return }
            let idx = selectedBundleIndices[examType] ?? 0
            guard newValue != dicomExams[examType]?[safe: idx]?.currentSliceIndex else { return }
            dicomExams[examType]?[idx].currentSliceIndex = newValue
        }
    }

    var patientName: String       { selectedBundle?.patientName       ?? "" }
    var studyDescription: String  { selectedBundle?.studyDescription  ?? "" }
    var seriesDescription: String { selectedBundle?.seriesDescription ?? "" }
    var modality: String          { selectedBundle?.modality          ?? "" }
    var sliceCount: Int           { selectedBundle?.sliceCount        ?? 0 }
    var currentSliceImage: CGImage? { selectedBundle?.currentSliceImage }

    private var selectedBundle: DICOMExamBundle? {
        guard let examType = selectedDICOMExamType,
              let bundles = dicomExams[examType], !bundles.isEmpty else { return nil }
        let idx = selectedBundleIndices[examType] ?? 0
        return bundles[safe: idx] ?? bundles[0]
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
        let idx = selectedBundleIndices[examType] ?? 0
        dicomExams[examType]?[idx].currentSliceIndex = index
    }

    func applyRemotePresetChange(_ preset: MedicalPreset) {
        selectedPreset = preset
    }

    // MARK: - Exam management (called by AppStore)

    func prepareForImport(examType: ExamType) {
        selectedDICOMExamType = examType
        isLoading = true
        errorMessage = nil
    }

    /// Appends the imported bundle and selects it immediately.
    func applyImportResult(_ bundle: DICOMExamBundle, examType: ExamType) {
        if dicomExams[examType] == nil { dicomExams[examType] = [] }
        dicomExams[examType]!.append(bundle)
        selectedBundleIndices[examType] = dicomExams[examType]!.count - 1
        selectedDICOMExamType = examType
        isLoading = false
    }

    func applyImportError(_ message: String) {
        errorMessage = message
        isLoading = false
    }

    /// Removes all bundles for the given exam type.
    func removeExam(_ examType: ExamType) {
        dicomExams[examType] = nil
        selectedBundleIndices[examType] = nil
        if selectedDICOMExamType == examType { selectedDICOMExamType = nil }
    }

    /// Removes a single bundle by id. Adjusts the selected index; clears the exam type if no bundles remain.
    func removeBundle(id: UUID, examType: ExamType) {
        dicomExams[examType]?.removeAll { $0.id == id }
        if dicomExams[examType]?.isEmpty == true { dicomExams[examType] = nil }
        let remaining = dicomExams[examType]?.count ?? 0
        if remaining == 0 {
            selectedBundleIndices[examType] = nil
            if selectedDICOMExamType == examType { selectedDICOMExamType = nil }
        } else {
            let current = selectedBundleIndices[examType] ?? 0
            selectedBundleIndices[examType] = min(current, remaining - 1)
        }
    }

    /// Selects a specific bundle within an exam type.
    func selectBundle(index: Int, examType: ExamType) {
        guard let bundles = dicomExams[examType], bundles.indices.contains(index) else { return }
        selectedBundleIndices[examType] = index
        selectedDICOMExamType = examType
    }

    // MARK: - Windowing re-application

    /// Re-applies the current preset to the raw buffers of the selected bundle.
    /// Calls `onComplete` on the MainActor when done.
    func reapplyWindowing(onComplete: @MainActor @escaping ([CGImage], ExamType) -> Void) {
        guard let examType = selectedDICOMExamType else { return }
        let idx = selectedBundleIndices[examType] ?? 0
        guard let bundle = dicomExams[examType]?[safe: idx],
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
        let idx = selectedBundleIndices[examType] ?? 0
        guard dicomExams[examType]?.indices.contains(idx) == true else { return }
        dicomExams[examType]![idx].sliceImages = images
        if dicomExams[examType]![idx].currentSliceIndex >= images.count {
            dicomExams[examType]![idx].currentSliceIndex = max(0, images.count - 1)
        }
        isLoading = false
    }
}

// MARK: - Array safe subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
