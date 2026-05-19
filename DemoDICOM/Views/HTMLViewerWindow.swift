//
//  HTMLViewerWindow.swift
//  DemoDICOM
//
//  Created by Igor Tarantino on 19/05/2026.
//


//
//  HTMLViewerWindow.swift
//  DemoDICOM
//

import SwiftUI
import WebKit

struct HTMLViewerWindow: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        Group {
            if let url = store.document.htmlFileURL {
                WebView(url: url)
                    .ignoresSafeArea()
            } else {
                ContentUnavailableView(
                    "No File Loaded",
                    systemImage: "doc.text",
                    description: Text("Open an HTML file from the toolbar.")
                )
            }
        }
        .navigationTitle("HTML Viewer")
    }
}

struct WebView: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        context.coordinator.load(url: url, into: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if webView.url != url {
            context.coordinator.load(url: url, into: webView)
        }
    }

    final class Coordinator {
        private var accessedURL: URL?

        func load(url: URL, into webView: WKWebView) {
            stopAccess()
            let didAccess = url.startAccessingSecurityScopedResource()
            if didAccess { accessedURL = url }
            defer {
                if didAccess {
                    stopAccess()
                }
            }

            guard let htmlString = try? String(contentsOf: url, encoding: .utf8) else {
                webView.loadHTMLString("<p>Failed to load file.</p>", baseURL: nil)
                return
            }
            webView.loadHTMLString(htmlString, baseURL: url.deletingLastPathComponent())
        }

        func stopAccess() {
            accessedURL?.stopAccessingSecurityScopedResource()
            accessedURL = nil
        }

        deinit { stopAccess() }
    }
}
