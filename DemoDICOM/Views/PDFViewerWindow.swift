//
//  PDFViewerWindow.swift
//  DemoDICOM
//

import SwiftUI
import PDFKit

struct PDFViewerWindow: View {
    @Environment(DICOMStore.self) private var store

    var body: some View {
        Group {
            if let url = store.pdfFileURL {
                PDFViewRepresentable(url: url)
                    .ignoresSafeArea()
            } else {
                ContentUnavailableView(
                    "No File Loaded",
                    systemImage: "exclamationmark.triangle",
                    description: Text("Open a PDF file from the toolbar.")
                )
            }
        }
        .navigationTitle("PDF Viewer")
    }
}

struct PDFViewRepresentable: UIViewRepresentable {
    let url: URL
    /// Current remote scroll/zoom state to apply. Pass `nil` (default) for non-synced viewers.
    var incomingState: SharedPDFState? = nil
    /// Called when the local user scrolls or zooms. Pass `nil` (default) for non-synced viewers.
    var onStateChange: ((SharedPDFState) -> Void)? = nil

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        context.coordinator.setup(pdfView: pdfView)
        context.coordinator.load(url: url, into: pdfView)
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        // Keep the closure fresh so the coordinator never captures a stale SwiftUI value.
        context.coordinator.onStateChange = onStateChange
        if pdfView.document?.documentURL != url {
            context.coordinator.load(url: url, into: pdfView)
        }
        if let state = incomingState {
            context.coordinator.apply(state: state, to: pdfView)
        }
    }

    // MARK: - Coordinator

    final class Coordinator {
        var onStateChange: ((SharedPDFState) -> Void)?

        private var accessedURL: URL?
        private var sendTask: Task<Void, Never>?
        private weak var pdfView: PDFView?

        // Prevents re-broadcasting state that was just received from a peer.
        private var isApplyingRemoteState = false
        // Prevents re-applying state that was already set (avoids interrupting user scroll).
        private var lastSentOrAppliedState: SharedPDFState?
        private var contentOffsetObservation: NSKeyValueObservation?

        // MARK: Setup

        func setup(pdfView: PDFView) {
            self.pdfView = pdfView
            NotificationCenter.default.addObserver(self, selector: #selector(handlePDFChange(_:)),
                name: .PDFViewPageChanged, object: pdfView)
            NotificationCenter.default.addObserver(self, selector: #selector(handlePDFChange(_:)),
                name: .PDFViewScaleChanged, object: pdfView)
            observeScrollView(in: pdfView)
        }

        private func observeScrollView(in view: UIView) {
            for sub in view.subviews {
                if let sv = sub as? UIScrollView {
                    contentOffsetObservation = sv.observe(\.contentOffset, options: [.new]) { [weak self] _, _ in
                        self?.scheduleSend()
                    }
                    return
                }
                observeScrollView(in: sub)
            }
        }

        // MARK: Notifications / scroll

        @objc private func handlePDFChange(_ notification: Notification) {
            guard !isApplyingRemoteState else { return }
            scheduleSend()
        }

        private func scheduleSend() {
            guard onStateChange != nil else { return }
            sendTask?.cancel()
            sendTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(150))
                guard !Task.isCancelled else { return }
                self?.captureAndSend()
            }
        }

        private func captureAndSend() {
            guard let pdfView, let state = captureState(from: pdfView) else { return }
            guard state != lastSentOrAppliedState else { return }
            lastSentOrAppliedState = state
            onStateChange?(state)
        }

        private func captureState(from pdfView: PDFView) -> SharedPDFState? {
            guard let document = pdfView.document,
                  let page = pdfView.currentPage else { return nil }
            let pt = pdfView.currentDestination?.point ?? .zero
            return SharedPDFState(
                page: document.index(for: page),
                x: (Double(pt.x) * 100).rounded() / 100,
                y: (Double(pt.y) * 100).rounded() / 100,
                scaleFactor: (Double(pdfView.scaleFactor) * 10000).rounded() / 10000
            )
        }

        // MARK: Apply remote state

        func apply(state: SharedPDFState, to pdfView: PDFView) {
            guard state != lastSentOrAppliedState else { return }
            guard let document = pdfView.document,
                  state.page < document.pageCount,
                  let page = document.page(at: state.page) else { return }
            lastSentOrAppliedState = state
            isApplyingRemoteState = true
            pdfView.scaleFactor = CGFloat(state.scaleFactor)
            pdfView.go(to: PDFDestination(page: page, at: CGPoint(x: state.x, y: state.y)))
            // Clear flag after PDFKit has had a chance to fire all synchronous notifications.
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(100))
                self?.isApplyingRemoteState = false
            }
        }

        // MARK: Document loading

        func load(url: URL, into pdfView: PDFView) {
            stopAccess()
            let didAccess = url.startAccessingSecurityScopedResource()
            if didAccess { accessedURL = url }
            defer { if didAccess { stopAccess() } }
            guard let document = PDFDocument(url: url) else {
                pdfView.document = nil
                return
            }
            pdfView.document = document
        }

        func stopAccess() {
            accessedURL?.stopAccessingSecurityScopedResource()
            accessedURL = nil
        }

        deinit {
            stopAccess()
            sendTask?.cancel()
            NotificationCenter.default.removeObserver(self)
        }
    }
}

#Preview {
    ContentUnavailableView("Content unavailable",
                           systemImage: "exclamationmark.triangle",
                           description: Text("Open a PDF file from the toolbar."))
}
