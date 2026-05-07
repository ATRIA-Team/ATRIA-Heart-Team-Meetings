//
//  DICOMStore.swift
//  DemoDICOM
//
//  Created on 25/03/2026.
//

import SwiftUI
import CoreGraphics
import DicomCore
import UniformTypeIdentifiers

// MARK: - AnnotationPanelStroke

struct AnnotationPanelStroke {
    let id: UUID
    var points: [CGPoint]
    let color: Color
    let lineWidth: CGFloat
}

// MARK: - LiveAnnotationSession

struct LiveAnnotationSession: Identifiable {
    let id: UUID
    let sliceIndex: Int
    let frozenImage: CGImage
    var strokes: [UUID: AnnotationPanelStroke] = [:]
}

// MARK: - DICOMExamBundle

/// All data for one loaded DICOM exam (Echo, CT, or Coro).
/// Each exam type gets its own independent buffer so they can all be loaded simultaneously.
struct DICOMExamBundle {
    var sliceImages: [CGImage] = []
    var rawPixelBuffers16: [([UInt16], Int, Int)] = []
    var currentSliceIndex: Int = 0
    var patientName: String = ""
    var studyDescription: String = ""
    var seriesDescription: String = ""
    var modality: String = ""

    var sliceCount: Int { sliceImages.count }
    var currentSliceImage: CGImage? {
        guard !sliceImages.isEmpty,
              currentSliceIndex >= 0,
              currentSliceIndex < sliceImages.count else { return nil }
        return sliceImages[currentSliceIndex]
    }
}

// MARK: - DICOMStore

@Observable
final class DICOMStore {

    // MARK: - SharePlay

    let sharePlay = SharePlayCoordinator()

    // MARK: - Drawing

    var drawing = DrawingManager()

    var isDrawingActive = false {
        didSet {
            guard isDrawingActive != oldValue else { return }
            sharePlay.send(DICOMSyncMessage(kind: isDrawingActive ? .drawingSpaceOpened : .drawingSpaceClosed))
        }
    }

    /// The exam type currently displayed in the shared window for all participants.
    /// Setting this broadcasts the change to every peer. For DICOM exam types it also
    /// switches `selectedDICOMExamType` so the existing slice-sync mechanism keeps working.
    var sharedWindowExamType: ExamType? {
        didSet {
            guard sharedWindowExamType != oldValue else { return }
            if let examType = sharedWindowExamType, [ExamType.echo, .ct, .coro].contains(examType) {
                selectedDICOMExamType = examType
            }
            sharePlay.send(DICOMSyncMessage(kind: .sharedWindowChanged(examType: sharedWindowExamType)))
        }
    }

    // MARK: - File URLs (non-DICOM)

    var htmlFileURL: URL?
    var pdfFileURL: URL?

    var medicalHistoryURL: URL? { didSet { broadcastDocumentChange(.medicalHistory, url: medicalHistoryURL) } }
    var vitalsURL: URL?         { didSet { broadcastDocumentChange(.vitals,          url: vitalsURL) } }
    var bloodTestURL: URL?      { didSet { broadcastDocumentChange(.bloodTests,      url: bloodTestURL) } }
    var otherFileURL: URL?      { didSet { broadcastDocumentChange(.other,           url: otherFileURL) } }

    // MARK: - Multi-DICOM storage

    /// Independent data bundle per DICOM exam type.
    /// Echo, CT, and Coro each get their own slice buffer so all three can be loaded at once.
    private(set) var dicomExams: [ExamType: DICOMExamBundle] = [:]

    /// The exam type currently shown in the viewer. Switches automatically on import;
    /// can also be changed by the user via the exam picker in ContentView.
    var selectedDICOMExamType: ExamType?

    /// DICOM exam types that have been successfully loaded, in display order.
    var loadedDICOMExamTypes: [ExamType] {
        [.echo, .ct, .coro].filter { !(dicomExams[$0]?.sliceImages.isEmpty ?? true) }
    }

    // MARK: - Computed DICOM state (reads from selected bundle)

    var sliceImages: [CGImage] {
        selectedBundle?.sliceImages ?? []
    }

    var currentSliceIndex: Int {
        get { selectedBundle?.currentSliceIndex ?? 0 }
        set {
            guard let examType = selectedDICOMExamType,
                  newValue != dicomExams[examType]?.currentSliceIndex else { return }
            dicomExams[examType]?.currentSliceIndex = newValue
            sharePlay.send(DICOMSyncMessage(kind: .sliceChanged(index: newValue)))
        }
    }

    var patientName: String      { selectedBundle?.patientName      ?? "" }
    var studyDescription: String { selectedBundle?.studyDescription ?? "" }
    var seriesDescription: String { selectedBundle?.seriesDescription ?? "" }
    var modality: String         { selectedBundle?.modality         ?? "" }
    var sliceCount: Int          { selectedBundle?.sliceCount       ?? 0 }
    var currentSliceImage: CGImage? { selectedBundle?.currentSliceImage }

    private var selectedBundle: DICOMExamBundle? {
        guard let examType = selectedDICOMExamType else { return nil }
        return dicomExams[examType]
    }

    // MARK: - Window preset (global, applies to selected exam)

    var selectedPreset: MedicalPreset = .softTissue {
        didSet {
            guard selectedPreset != oldValue else { return }
            sharePlay.send(DICOMSyncMessage(kind: .presetChanged(rawValue: selectedPreset.rawValue)))
            reapplyWindowing()
        }
    }

    // MARK: - Loading / error state

    private(set) var isLoading: Bool = false
    var errorMessage: String?

    // MARK: - Live annotation sessions

    private(set) var liveSessions: [UUID: LiveAnnotationSession] = [:]
    var isAnnotationPanelVisible: Bool { !liveSessions.isEmpty }
    private var sessionOpenCounts: [UUID: Int] = [:]
    private(set) var locallyOpenSessionCount: [UUID: Int] = [:]

    // MARK: - Annotation session lifecycle (local)

    @MainActor
    func createAnnotationSession(id: UUID, sliceIndex: Int, image: CGImage) {
        liveSessions[id] = LiveAnnotationSession(id: id, sliceIndex: sliceIndex, frozenImage: image)
        sessionOpenCounts[id] = 1
        locallyOpenSessionCount[id, default: 0] += 1
        sharePlay.send(DICOMSyncMessage(kind: .annotationSessionOpened(sessionID: id, sliceIndex: sliceIndex)))
    }

    @MainActor
    func joinAnnotationSession(id: UUID) {
        guard let session = liveSessions[id] else { return }
        sessionOpenCounts[id, default: 0] += 1
        locallyOpenSessionCount[id, default: 0] += 1
        sharePlay.send(DICOMSyncMessage(kind: .annotationSessionOpened(sessionID: id, sliceIndex: session.sliceIndex)))
    }

    @MainActor
    func closeAnnotationSession(id: UUID) {
        locallyOpenSessionCount[id, default: 0] = max(0, (locallyOpenSessionCount[id] ?? 0) - 1)
        if locallyOpenSessionCount[id] == 0 { locallyOpenSessionCount.removeValue(forKey: id) }

        let newCount = max(0, (sessionOpenCounts[id] ?? 0) - 1)
        sessionOpenCounts[id] = newCount
        if newCount == 0 {
            liveSessions.removeValue(forKey: id)
            sessionOpenCounts.removeValue(forKey: id)
        }
        sharePlay.send(DICOMSyncMessage(kind: .annotationSessionClosed(sessionID: id)))
    }

    // MARK: - Annotation session lifecycle (remote)

    @MainActor
    func remoteAnnotationSessionOpened(sessionID: UUID, sliceIndex: Int) {
        if liveSessions[sessionID] != nil {
            sessionOpenCounts[sessionID, default: 0] += 1
        } else {
            guard sliceIndex >= 0, sliceIndex < sliceImages.count else { return }
            let image = sliceImages[sliceIndex]
            liveSessions[sessionID] = LiveAnnotationSession(id: sessionID, sliceIndex: sliceIndex, frozenImage: image)
            sessionOpenCounts[sessionID] = 1
        }
    }

    @MainActor
    func remoteAnnotationSessionClosed(sessionID: UUID) {
        let newCount = max(0, (sessionOpenCounts[sessionID] ?? 0) - 1)
        sessionOpenCounts[sessionID] = newCount
        if newCount == 0 {
            liveSessions.removeValue(forKey: sessionID)
            sessionOpenCounts.removeValue(forKey: sessionID)
        }
    }

    // MARK: - Stroke management

    @MainActor
    func receiveAnnotation2DPoint(_ msg: Annotation2DPointMessage) {
        guard liveSessions[msg.sessionID] != nil else { return }
        let pt = CGPoint(x: CGFloat(msg.x), y: CGFloat(msg.y))
        let color = Color(red: Double(msg.colorR), green: Double(msg.colorG), blue: Double(msg.colorB))
        if msg.isStart {
            liveSessions[msg.sessionID]?.strokes[msg.strokeID] = AnnotationPanelStroke(
                id: msg.strokeID, points: [pt], color: color, lineWidth: CGFloat(msg.lineWidth)
            )
        } else {
            liveSessions[msg.sessionID]?.strokes[msg.strokeID]?.points.append(pt)
        }
    }

    @MainActor
    func removeAnnotationStrokes(sessionID: UUID, ids: Set<UUID>) {
        for id in ids { liveSessions[sessionID]?.strokes.removeValue(forKey: id) }
    }

    // MARK: - Init

    init() {
        sharePlay.store = self
    }

    // MARK: - SharePlay API

    @MainActor
    func applySharePlayMessage(_ message: DICOMSyncMessage) {
        switch message.kind {
        case .sliceChanged(let index):
            guard index >= 0, index < sliceCount else { return }
            currentSliceIndex = index
        case .presetChanged(let rawValue):
            guard let preset = MedicalPreset(rawValue: rawValue) else { return }
            selectedPreset = preset
        case .annotationSessionOpened(let sessionID, let sliceIndex):
            remoteAnnotationSessionOpened(sessionID: sessionID, sliceIndex: sliceIndex)
        case .annotationSessionClosed(let sessionID):
            remoteAnnotationSessionClosed(sessionID: sessionID)
        case .drawingSpaceOpened:
            isDrawingActive = true
        case .drawingSpaceClosed:
            isDrawingActive = false
        case .sharedWindowChanged(let examType):
            sharedWindowExamType = examType
        case .examReady, .examNotReady, .sessionStarted, .clearDrawings, .removeAnnotationStrokes:
            break
        }
    }

    // MARK: - Broadcasting helpers

    func broadcastDocumentChange(_ examType: ExamType, url: URL?) {
        if let url {
            sharePlay.broadcastExamReady(type: examType, metadata: .document(fileName: url.deletingPathExtension().lastPathComponent))
        } else {
            sharePlay.broadcastExamNotReady(type: examType)
        }
    }

    /// Re-broadcasts readiness for every loaded exam. Called by SharePlayCoordinator
    /// when a session starts or new peers join.
    @MainActor
    func broadcastAllLoadedExams() {
        for (examType, bundle) in dicomExams where !bundle.sliceImages.isEmpty {
            sharePlay.broadcastExamReady(
                type: examType,
                metadata: .dicom(sliceCount: bundle.sliceCount, seriesDescription: bundle.seriesDescription, patientName: bundle.patientName)
            )
        }
        if let url = medicalHistoryURL { broadcastDocumentChange(.medicalHistory, url: url) }
        if let url = vitalsURL         { broadcastDocumentChange(.vitals,          url: url) }
        if let url = bloodTestURL      { broadcastDocumentChange(.bloodTests,      url: url) }
        if let url = otherFileURL      { broadcastDocumentChange(.other,           url: url) }
    }

    // MARK: - DICOM Import

    /// Import DICOM slices from a folder. Each exam type gets its own independent buffer.
    @MainActor
    func importFolder(url: URL, examType: ExamType = .ct) {
        isLoading = true
        errorMessage = nil
        dicomExams[examType] = DICOMExamBundle()   // clear only this exam's data
        selectedDICOMExamType = examType            // switch view to this exam
        sharePlay.broadcastExamNotReady(type: examType)

        let capturedExamType = examType
        Task.detached { [weak self] in
            guard let self else { return }
            await self.performImport(url: url, examType: capturedExamType)
        }
    }

    // MARK: - Private

    private func performImport(url: URL, examType: ExamType) async {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        do {
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

            guard !dicomFiles.isEmpty else {
                await updateError("No DICOM files found in the selected folder. Make sure you selected the right folder.")
                return
            }

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
                if compressedCount == totalCount {
                    await updateError(
                        "All \(compressedCount) files use a compressed transfer syntax, but none could be decoded.\n\n" +
                        "Single-frame JPEG and JPEG2000 DICOM images are supported.\n\n" +
                        "Fallback: dcmconv --write-xfer-little input.dcm output.dcm"
                    )
                } else if compressedCount > 0 {
                    await updateError("\(compressedCount) of \(totalCount) files used compressed transfer syntaxes and were skipped. No decodable slices remained.")
                } else {
                    await updateError("Could not decode any DICOM slices from this folder.")
                }
                return
            }

            sliceEntries.sort { $0.instanceNumber < $1.instanceNumber }

            let patientInfo  = firstDecoder?.getPatientInfo()  ?? [:]
            let studyInfo    = firstDecoder?.getStudyInfo()    ?? [:]
            let seriesInfo   = firstDecoder?.getSeriesInfo()   ?? [:]
            let modalityStr  = firstDecoder?.info(for: 0x00080060) ?? ""

            let presetSnap = await MainActor.run { self.selectedPreset }
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
                let preset = DCMWindowingProcessor.getPresetValues(preset: presetSnap)
                windowCenter = preset.center
                windowWidth  = preset.width
            }

            var images: [CGImage] = []
            var rawBuffers: [([UInt16], Int, Int)] = []
            for entry in sliceEntries {
                rawBuffers.append((entry.pixels16, entry.width, entry.height))
                if let windowedData = DCMWindowingProcessor.applyWindowLevel(pixels16: entry.pixels16, center: windowCenter, width: windowWidth),
                   let cgImage = CGImage.fromDICOMWindowedData(windowedData, width: entry.width, height: entry.height) {
                    images.append(cgImage)
                }
            }

            await MainActor.run {
                self.dicomExams[examType] = DICOMExamBundle(
                    sliceImages: images,
                    rawPixelBuffers16: rawBuffers,
                    currentSliceIndex: images.count / 2,
                    patientName: patientInfo["Name"] ?? "",
                    studyDescription: studyInfo["StudyDescription"] ?? "",
                    seriesDescription: seriesInfo["SeriesDescription"] ?? "",
                    modality: modalityStr
                )
                self.selectedDICOMExamType = examType
                self.isLoading = false
                self.sharePlay.broadcastExamReady(
                    type: examType,
                    metadata: .dicom(
                        sliceCount: images.count,
                        seriesDescription: seriesInfo["SeriesDescription"] ?? "",
                        patientName: patientInfo["Name"] ?? ""
                    )
                )
            }

        } catch {
            await updateError("Import failed: \(error.localizedDescription)")
        }
    }

    /// Re-applies the current preset to the raw buffers of the selected exam only.
    private func reapplyWindowing() {
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
                if let windowedData = DCMWindowingProcessor.applyWindowLevel(pixels16: pixels, center: presetValues.center, width: presetValues.width),
                   let cgImage = CGImage.fromDICOMWindowedData(windowedData, width: width, height: height) {
                    images.append(cgImage)
                }
            }

            await MainActor.run { [weak self] in
                guard let self else { return }
                self.dicomExams[examType]?.sliceImages = images
                if (self.dicomExams[examType]?.currentSliceIndex ?? 0) >= images.count {
                    self.dicomExams[examType]?.currentSliceIndex = max(0, images.count - 1)
                }
                self.isLoading = false
            }
        }
    }

    @MainActor
    private func updateError(_ message: String) {
        errorMessage = message
        isLoading = false
    }
}
