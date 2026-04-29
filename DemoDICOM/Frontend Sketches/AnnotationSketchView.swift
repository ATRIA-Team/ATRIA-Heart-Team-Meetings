//
//  AnnotationSketchView.swift
//  DemoDICOM
//
//  Created by Igor Tarantino on 29/04/2026.
//

import SwiftUI

struct AnnotationSketchView: View {
    
    @State private var isShareplayActive: Bool = false
    
    var body: some View {
        
        VStack {
            
            Text("Pre-op Meeting")
                .font(.largeTitle)
            
            HStack {
                
                Text("3 people in meeting")
                
                Button {
                    // Activate Shareplay session
                    print("Shareplay active")
                    isShareplayActive.toggle()
                } label: {
                    Label(!isShareplayActive ? "Not shared" : "Shared", systemImage: "shareplay")
                }
                .foregroundStyle(Color.primary)
                .background(isShareplayActive ? Color.green : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: .infinity))
            }
            .padding(.vertical)
            
            Text("Sketches")
                .font(.title)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(0..<5, id: \.self) { index in
                        SketchCard(title: "Sketch \(index + 1)", date: "Today")
                    }
                }
                .padding()
            }
            
        }
    }
}

struct SketchCard: View {
    let title: String
    let date: String

    var body: some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 8)
                .fill(LinearGradient(
                    gradient: Gradient(colors: [.blue.opacity(0.3), .purple.opacity(0.3)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 80, height: 80)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(white: 0.1))
        .cornerRadius(12)
    }
}

struct SketchCard2: View {
    var title: String
    var date: String

    var body: some View {
        RoundedRectangle(cornerRadius: 25)
    }
}

#Preview(windowStyle: .automatic) {
//    SketchCard2(title: "Yo bro", date: "Everything is alright")
    AnnotationSketchView()
}
