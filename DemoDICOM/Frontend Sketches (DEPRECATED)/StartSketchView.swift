//
//  StartSketchView.swift
//  DemoDICOM
//
//  Created by Igor Tarantino on 27/04/2026.
//

import SwiftUI

struct StartSketchView: View {
    
    var body: some View {
        
        Button {
            print("Add files")
        } label: {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 50))
                .padding(.vertical)
        }
        .buttonBorderShape(.roundedRectangle)
        .frame(width: 100, height: 100)
        
        Button {
            print("Start FaceTime")
        } label: {
            Image(systemName: "video")
                .font(.system(size: 49))
                .padding(20)
                .padding(.vertical)
        }
        .buttonBorderShape(.roundedRectangle)
        
    }
}

#Preview(windowStyle: .automatic) {
    StartSketchView()
}
