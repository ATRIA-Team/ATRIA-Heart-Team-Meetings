//
//  DocumentStoreTests.swift
//  ATRIATests
//

import Testing
import Foundation
@testable import ATRIA

// MARK: - DocumentStoreTests

@Suite("DocumentStore")
struct DocumentStoreTests {

    private let urlA = URL(fileURLWithPath: "/tmp/a.pdf")
    private let urlB = URL(fileURLWithPath: "/tmp/b.pdf")

    // MARK: - addMedicalHistory

    @Test("addMedicalHistory appends the URL")
    func addMedicalHistory() {
        let store = DocumentStore()
        store.addMedicalHistory(urlA)
        #expect(store.medicalHistoryURLs.contains(urlA))
    }

    @Test("addMedicalHistory ignores duplicate URLs")
    func addMedicalHistoryNoDuplicates() {
        let store = DocumentStore()
        store.addMedicalHistory(urlA)
        store.addMedicalHistory(urlA)
        #expect(store.medicalHistoryURLs.count == 1)
    }

    @Test("addMedicalHistory supports multiple distinct URLs")
    func addMedicalHistoryMultiple() {
        let store = DocumentStore()
        store.addMedicalHistory(urlA)
        store.addMedicalHistory(urlB)
        #expect(store.medicalHistoryURLs.count == 2)
        #expect(store.medicalHistoryURLs.contains(urlA))
        #expect(store.medicalHistoryURLs.contains(urlB))
    }

    // MARK: - removeMedicalHistory

    @Test("removeMedicalHistory removes the specified URL")
    func removeMedicalHistory() {
        let store = DocumentStore()
        store.addMedicalHistory(urlA)
        store.addMedicalHistory(urlB)
        store.removeMedicalHistory(urlA)
        #expect(!store.medicalHistoryURLs.contains(urlA))
        #expect(store.medicalHistoryURLs.contains(urlB))
    }

    @Test("removeMedicalHistory leaves the list empty when the last URL is removed")
    func removeMedicalHistoryLast() {
        let store = DocumentStore()
        store.addMedicalHistory(urlA)
        store.removeMedicalHistory(urlA)
        #expect(store.medicalHistoryURLs.isEmpty)
    }

    // MARK: - addVitals / addBloodTests / addOther

    @Test("addVitals appends the URL")
    func addVitals() {
        let store = DocumentStore()
        store.addVitals(urlA)
        #expect(store.vitalsURLs.contains(urlA))
    }

    @Test("addBloodTests appends the URL")
    func addBloodTests() {
        let store = DocumentStore()
        store.addBloodTests(urlA)
        #expect(store.bloodTestURLs.contains(urlA))
    }

    @Test("addOther appends the URL")
    func addOther() {
        let store = DocumentStore()
        store.addOther(urlA)
        #expect(store.otherFileURLs.contains(urlA))
    }

    // MARK: - removeVitals / removeBloodTests / removeOther

    @Test("removeVitals removes the specified URL")
    func removeVitals() {
        let store = DocumentStore()
        store.addVitals(urlA)
        store.addVitals(urlB)
        store.removeVitals(urlA)
        #expect(!store.vitalsURLs.contains(urlA))
        #expect(store.vitalsURLs.contains(urlB))
    }

    @Test("removeVitals leaves the list empty when the last URL is removed")
    func removeVitalsLast() {
        let store = DocumentStore()
        store.addVitals(urlA)
        store.removeVitals(urlA)
        #expect(store.vitalsURLs.isEmpty)
    }

    @Test("removeBloodTests removes the specified URL")
    func removeBloodTests() {
        let store = DocumentStore()
        store.addBloodTests(urlA)
        store.addBloodTests(urlB)
        store.removeBloodTests(urlA)
        #expect(!store.bloodTestURLs.contains(urlA))
        #expect(store.bloodTestURLs.contains(urlB))
    }

    @Test("removeBloodTests leaves the list empty when the last URL is removed")
    func removeBloodTestsLast() {
        let store = DocumentStore()
        store.addBloodTests(urlA)
        store.removeBloodTests(urlA)
        #expect(store.bloodTestURLs.isEmpty)
    }

    @Test("removeOther removes the specified URL")
    func removeOther() {
        let store = DocumentStore()
        store.addOther(urlA)
        store.addOther(urlB)
        store.removeOther(urlA)
        #expect(!store.otherFileURLs.contains(urlA))
        #expect(store.otherFileURLs.contains(urlB))
    }

    @Test("removeOther leaves the list empty when the last URL is removed")
    func removeOtherLast() {
        let store = DocumentStore()
        store.addOther(urlA)
        store.removeOther(urlA)
        #expect(store.otherFileURLs.isEmpty)
    }

    // MARK: - documentURLs(for:)

    @Test("documentURLs returns all URLs for each document exam type")
    func documentURLsMapping() {
        let store = DocumentStore()
        let u1 = URL(fileURLWithPath: "/a")
        let u2 = URL(fileURLWithPath: "/b")
        let u3 = URL(fileURLWithPath: "/c")
        let u4 = URL(fileURLWithPath: "/d")

        store.addMedicalHistory(u1)
        store.addVitals(u2)
        store.addBloodTests(u3)
        store.addOther(u4)

        #expect(store.documentURLs(for: .medicalHistory).contains(u1))
        #expect(store.documentURLs(for: .vitals).contains(u2))
        #expect(store.documentURLs(for: .bloodTests).contains(u3))
        #expect(store.documentURLs(for: .other).contains(u4))
    }

    @Test("documentURLs returns empty for DICOM exam types")
    func documentURLsEmptyForDICOM() {
        let store = DocumentStore()
        #expect(store.documentURLs(for: .echo).isEmpty)
        #expect(store.documentURLs(for: .ct).isEmpty)
        #expect(store.documentURLs(for: .coro).isEmpty)
    }

    // MARK: - documentURL(for:) — active / first URL

    @Test("documentURL returns the first URL when no active URL is set")
    func documentURLReturnsFirst() {
        let store = DocumentStore()
        store.addMedicalHistory(urlA)
        store.addMedicalHistory(urlB)
        #expect(store.documentURL(for: .medicalHistory) == urlA)
    }

    @Test("documentURL returns the active URL when one is explicitly set")
    func documentURLReturnsActive() {
        let store = DocumentStore()
        store.addMedicalHistory(urlA)
        store.addMedicalHistory(urlB)
        store.setActiveDocumentURL(urlB, examType: .medicalHistory)
        #expect(store.documentURL(for: .medicalHistory) == urlB)
    }

    @Test("documentURL returns nil for DICOM exam types")
    func documentURLNilForDICOM() {
        let store = DocumentStore()
        #expect(store.documentURL(for: .echo) == nil)
        #expect(store.documentURL(for: .ct) == nil)
        #expect(store.documentURL(for: .coro) == nil)
    }

    // MARK: - sharedWindowExamType

    @Test("applySharedWindow sets the shared exam type")
    func applySharedWindow() {
        let store = DocumentStore()
        store.applySharedWindow(.ct)
        #expect(store.sharedWindowExamType == .ct)
    }

    @Test("applySharedWindow with nil clears the exam type and PDF state")
    func applySharedWindowNilClearsBoth() {
        let store = DocumentStore()
        store.applySharedWindow(.ct)
        store.applyRemotePDFState(SharedPDFState(page: 1, x: 0, y: 0, scaleFactor: 1))
        store.applySharedWindow(nil)
        #expect(store.sharedWindowExamType == nil)
        #expect(store.sharedPDFState == nil)
    }

    @Test("applySharedWindow to a non-nil value does not clear PDF state")
    func applySharedWindowNonNilKeepsPDF() {
        let store = DocumentStore()
        let pdfState = SharedPDFState(page: 2, x: 10, y: 20, scaleFactor: 1.5)
        store.applyRemotePDFState(pdfState)
        store.applySharedWindow(.echo)
        #expect(store.sharedPDFState == pdfState)
    }

    // MARK: - sharedAnnotationSessionID

    @Test("applySharedAnnotation sets the session ID")
    func applySharedAnnotation() {
        let store = DocumentStore()
        let id = UUID()
        store.applySharedAnnotation(id)
        #expect(store.sharedAnnotationSessionID == id)
    }

    @Test("applySharedAnnotation with nil clears the session ID")
    func applySharedAnnotationNil() {
        let store = DocumentStore()
        store.applySharedAnnotation(UUID())
        store.applySharedAnnotation(nil)
        #expect(store.sharedAnnotationSessionID == nil)
    }

    // MARK: - sharedPDFState

    @Test("applyRemotePDFState stores the state")
    func applyRemotePDFState() {
        let store = DocumentStore()
        let state = SharedPDFState(page: 3, x: 100, y: 200, scaleFactor: 2.0)
        store.applyRemotePDFState(state)
        #expect(store.sharedPDFState == state)
    }

    @Test("setLocalPDFState stores the state")
    func setLocalPDFState() {
        let store = DocumentStore()
        let state = SharedPDFState(page: 5, x: 0, y: 50, scaleFactor: 1.0)
        store.setLocalPDFState(state)
        #expect(store.sharedPDFState == state)
    }

    @Test("setLocalPDFState with nil clears the state")
    func setLocalPDFStateNil() {
        let store = DocumentStore()
        store.setLocalPDFState(SharedPDFState(page: 1, x: 0, y: 0, scaleFactor: 1))
        store.setLocalPDFState(nil)
        #expect(store.sharedPDFState == nil)
    }
}
