//
//  TabSketchView.swift
//  DemoDICOM
//
//  Created by Igor Tarantino on 29/04/2026.
//

import SwiftUI

struct TabSketchView: View {
    
    var body: some View {
        
        TabView {
            Tab("Meeting", systemImage: "heart") {
                UploadFileSketchView()
            }
            Tab("Meeting", systemImage: "heart") {
                AnnotationSketchView()
            }
        }
    }
}

#Preview(windowStyle: .automatic) {
    TabSketchView()
}
