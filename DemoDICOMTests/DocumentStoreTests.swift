//
//  DocumentStoreTests.swift
//  DemoDICOMTests
//

import Testing
import Foundation
@testable import DemoDICOM

// MARK: - DocumentStoreTests

@Suite("DocumentStore")
struct DocumentStoreTests {

    private let sampleURL = URL(fileURLWithPath: "/tmp/sample.pdf")

    // MARK: - URL setters

    @Test("setMedicalHistory stores the URL")
    func setMedicalHistory() {
        let store = DocumentStore()
        store.setMedicalHistory(sampleURL)
        #expect(store.medicalHistoryURL == sampleURL)
    }

    @Test("setMedicalHistory with nil clears the URL")
    func setMedicalHistoryNil() {
        let store = DocumentStore()
        store.setMedicalHistory(sampleURL)
        store.setMedicalHistory(nil)
        #expect(store.medicalHistoryURL == nil)
    }

    @Test("setVitals stores the URL")
    func setVitals() {
        let store = DocumentStore()
        store.setVitals(sampleURL)
        #expect(store.vitalsURL == sampleURL)
    }

    @Test("setBloodTests stores the URL")
    func setBloodTests() {
        let store = DocumentStore()
        store.setBloodTests(sampleURL)
        #expect(store.bloodTestURL == sampleURL)
    }

    @Test("setOther stores the URL")
    func setOther() {
        let store = DocumentStore()
        store.setOther(sampleURL)
        #expect(store.otherFileURL == sampleURL)
    }

    // MARK: - documentURL(for:)

    @Test("documentURL returns the correct URL for each document exam type")
    func documentURLMapping() {
        let store = DocumentStore()
        let urlA = URL(fileURLWithPath: "/a")
        let urlB = URL(fileURLWithPath: "/b")
        let urlC = URL(fileURLWithPath: "/c")
        let urlD = URL(fileURLWithPath: "/d")

        store.setMedicalHistory(urlA)
        store.setVitals(urlB)
        store.setBloodTests(urlC)
        store.setOther(urlD)

        #expect(store.documentURL(for: .medicalHistory) == urlA)
        #expect(store.documentURL(for: .vitals) == urlB)
        #expect(store.documentURL(for: .bloodTests) == urlC)
        #expect(store.documentURL(for: .other) == urlD)
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
