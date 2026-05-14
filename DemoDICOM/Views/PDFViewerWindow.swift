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
        private weak var scrollView: UIScrollView?

        // Raised while applying a received state so KVO/notification observers don't re-broadcast.
        private var isApplyingRemoteState = false
        // Last state sent or applied — skips no-op updates in both directions.
        private var lastSentOrAppliedState: SharedPDFState?
        private var contentOffsetObservation: NSKeyValueObservation?
        // Cancellable work item for the async contentOffset application after a scale change.
        private var applyWorkItem: DispatchWorkItem?

        // MARK: Setup

        func setup(pdfView: PDFView) {
            self.pdfView = pdfView
            NotificationCenter.default.addObserver(self, selector: #selector(handleScaleChanged(_:)),
                name: .PDFViewScaleChanged, object: pdfView)
            self.scrollView = findScrollView(in: pdfView)
            contentOffsetObservation = scrollView?.observe(\.contentOffset, options: [.new]) { [weak self] _, _ in
                // Guard prevents re-broadcasting while we apply a remote state.
                guard !(self?.isApplyingRemoteState ?? true) else { return }
                self?.scheduleSend()
            }
        }

        private func findScrollView(in view: UIView) -> UIScrollView? {
            for sub in view.subviews {
                if let sv = sub as? UIScrollView { return sv }
                if let found = findScrollView(in: sub) { return found }
            }
            return nil
        }

        // MARK: Scale change (pinch-to-zoom may not always move contentOffset)

        @objc private func handleScaleChanged(_ notification: Notification) {
            guard !isApplyingRemoteState else { return }
            scheduleSend()
        }

        // MARK: Debounced send (~50 ms gives real-time feel without flooding the network)

        private func scheduleSend() {
            guard onStateChange != nil else { return }
            sendTask?.cancel()
            sendTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(50))
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

        // State is encoded as normalized scroll-view content offset so it round-trips
        // perfectly without PDFDestination coordinate ambiguity.
        private func captureState(from pdfView: PDFView) -> SharedPDFState? {
            guard let document = pdfView.document,
                  let page = pdfView.currentPage,
                  let sv = scrollView,
                  sv.contentSize.width > 0, sv.contentSize.height > 0 else { return nil }
            let nx = Double(sv.contentOffset.x / sv.contentSize.width)
            let ny = Double(sv.contentOffset.y / sv.contentSize.height)
            return SharedPDFState(
                page: document.index(for: page),
                x: (nx * 100000).rounded() / 100000,
                y: (ny * 100000).rounded() / 100000,
                scaleFactor: (Double(pdfView.scaleFactor) * 10000).rounded() / 10000
            )
        }

        // MARK: Apply remote state

        func apply(state: SharedPDFState, to pdfView: PDFView) {
            guard state != lastSentOrAppliedState else { return }
            guard let sv = scrollView else { return }
            lastSentOrAppliedState = state
            isApplyingRemoteState = true

            // Cancel any previously pending offset application (newest state wins).
            applyWorkItem?.cancel()

            pdfView.scaleFactor = CGFloat(state.scaleFactor)

            // Apply content offset after the layout pass triggered by the scale change.
            let work = DispatchWorkItem { [weak self, weak sv] in
                guard let self, let sv else { return }
                let offset = CGPoint(
                    x: CGFloat(state.x) * sv.contentSize.width,
                    y: CGFloat(state.y) * sv.contentSize.height
                )
                sv.setContentOffset(offset, animated: false)
                self.isApplyingRemoteState = false
            }
            applyWorkItem = work
            DispatchQueue.main.async(execute: work)
        }

        // MARK: Document loading

        func load(url: URL, into pdfView: PDFView) {
            stopAccess()
            let didAccess = url.startAccessingSecurityScopedResource()
            if didAccess { accessedURL = url }
            guard let document = PDFDocument(url: url) else {
                if didAccess { stopAccess() }
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
            applyWorkItem?.cancel()
            contentOffsetObservation = nil
            NotificationCenter.default.removeObserver(self)
        }
    }
}

#Preview {
    ContentUnavailableView("Content unavailable",
                           systemImage: "exclamationmark.triangle",
                           description: Text("Open a PDF file from the toolbar."))
}
