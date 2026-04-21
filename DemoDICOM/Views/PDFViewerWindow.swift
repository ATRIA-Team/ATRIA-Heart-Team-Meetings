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
                    systemImage: "doc.pdf",
                    description: Text("Open a PDF file from the toolbar.")
                )
            }
        }
        .navigationTitle("PDF Viewer")
    }
}

struct PDFViewRepresentable: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        context.coordinator.load(url: url, into: pdfView)
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        if pdfView.document?.documentURL != url {
            context.coordinator.load(url: url, into: pdfView)
        }
    }

    final class Coordinator {
        private var accessedURL: URL?

        func load(url: URL, into pdfView: PDFView) {
            stopAccess()
            let didAccess = url.startAccessingSecurityScopedResource()
            if didAccess { accessedURL = url }
            defer {
                if didAccess {
                    stopAccess()
                }
            }

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

        deinit { stopAccess() }
    }
}
