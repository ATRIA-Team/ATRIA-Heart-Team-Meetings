//
//  NativeShareButton.swift
//  DemoDICOMmac
//

import SwiftUI
import AppKit

struct NativeShareButton<Label: View>: View {
    let items: [Any]
    @ViewBuilder var label: () -> Label
    @State private var anchor: NSView?

    var body: some View {
        Button {
            guard let anchor else { return }
            let picker = NSSharingServicePicker(items: items)
            picker.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .minY)
        } label: {
            label()
        }
        .buttonStyle(.plain)
        .background(AnchorCapture(view: $anchor))
    }
}

private struct AnchorCapture: NSViewRepresentable {
    @Binding var view: NSView?

    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        DispatchQueue.main.async { self.view = v }
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
