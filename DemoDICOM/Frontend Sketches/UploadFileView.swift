//
//  UploadFileSketchView.swift
//  DemoDICOM
//
//  Created by Igor Tarantino on 28/04/2026.
//

import SwiftUI

struct UploadFileSketchView: View {
    
    @State private var isShareplayActive: Bool = false
    @State private var isShareplayMeeting: Bool = false
    
    @State private var showAlert = false
    
    var body: some View {
        
        ZStack {
            
            //Color.red
            
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
                
                Text("Uploadaed files")
                    .font(.title)
                
                VStack(alignment: .center) {
                    Button {
                        
                    } label: {
                        HStack {
                            Circle()
                                .foregroundStyle(Color.green)
                                .frame(width: 55, height: 55)
                                .padding(5)
                                .overlay {
                                    Image(systemName: "person.fill.checkmark")
                                        .font(.system(size: 25))
                                }
                            VStack(alignment: .leading) {
                                Text("DICOM file")
                                Text("Status")
                                    .font(.callout)
                                    .foregroundStyle(Color.secondary)
                            }
                            Spacer()
                            Image(systemName: "document.viewfinder")
                        }
                        .frame(width: 400)
                    }
                    .buttonBorderShape(.roundedRectangle)
                    
                    Button {
                        
                    } label: {
                        HStack {
                            Circle()
                                .foregroundStyle(Color.yellow)
                                .frame(width: 55, height: 55)
                                .padding(5)
                                .overlay {
                                    Image(systemName: "person.fill.questionmark")
                                        .font(.system(size: 25))
                                }
                            VStack(alignment: .leading) {
                                Text("Image file")
                                Text("Status")
                                    .font(.callout)
                                    .foregroundStyle(Color.secondary)
                            }
                            Spacer()
                            Image(systemName: "photo")
                        }
                        .frame(width: 400)
                    }
                    .buttonBorderShape(.roundedRectangle)
                    
                    Button {
                        
                    } label: {
                        HStack {
                            Circle()
                                .foregroundStyle(Color.red)
                                .frame(width: 55, height: 55)
                                .padding(5)
                                .overlay {
                                    Image(systemName: "person.fill.xmark")
                                        .font(.system(size: 25))
                                }
                            VStack(alignment: .leading) {
                                Text("Clinical folder")
                                Text("Status")
                                    .font(.callout)
                                    .foregroundStyle(Color.secondary)
                            }
                            Spacer()
                            Image(systemName: "document.on.document")
                        }
                        .frame(width: 400)
                    }
                    .buttonBorderShape(.roundedRectangle)
                }
                
                Button {
                    isShareplayMeeting.toggle()
                } label: {
                    Label(!isShareplayMeeting ? "Start meeting" : "Stop meting", systemImage: !isShareplayMeeting ? "video" : "stop")
                }
                .foregroundStyle(!isShareplayMeeting ? Color.primary : Color.black)
                .background(isShareplayMeeting ? Color.white : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: .infinity))
                .padding(.vertical)
                .onChange(of: isShareplayMeeting) { oldValue, newValue in
                    if oldValue == true && newValue == false {
                        showAlert = true
                    }
                }
                .alert("Meeting concluded", isPresented: $showAlert) {
                    Button("Export only Snapshots") { }
                    Button("Export PDF and Snapshots") { }
                }
            }
        }
    }
}

#Preview(windowStyle: .automatic) {
    UploadFileSketchView()
        .frame(width: 500, height: 800)
}
