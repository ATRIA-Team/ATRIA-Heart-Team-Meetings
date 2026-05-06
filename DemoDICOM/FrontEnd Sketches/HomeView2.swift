//
//  HomeView2.swift
//  DemoDICOM
//
//  Created by Igor Tarantino on 06/05/2026.
//

import SwiftUI

struct HomeView2: View {
    
    @State private var noMeetings: Bool = true
    
    var body: some View {
        
        HStack(spacing: 150) {
            
            Rectangle()
                .foregroundColor(.clear)
                .frame(width: 482, height: 586)
                .background(.black.opacity(0.08))
                .background(Color(red: 0.84, green: 0.84, blue: 0.84).opacity(0.45))
                .cornerRadius(100)
                .overlay {
                    
                    VStack(spacing: 35) {
                        
                        VStack(spacing: 1) {
                            Text("09:41")
                                .font(.system(size: 50, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("01 Jun 2026")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                        }
                        .padding(.top, 25)
                        
                        Text("Upcoming meetings")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(.white)
                        
                        if noMeetings {
                            
                            VStack {
                                Image(systemName: "video.slash")
                                    .font(.system(size: 50))
                                
                                Text("There are no scheduled meetings")
                                    .font(.callout)
                            }
                            .foregroundStyle(.secondary)
                            .padding(.top, 85)
                            
                        } else {
                            
                        }
                        
                        Spacer()
                    }
                }
            
            VStack(spacing: 30) {
                
                HStack(spacing: 30) {
                    
                    Button {
                        
                    } label: {
                        Rectangle()
                            .foregroundColor(.clear)
                            .frame(width: 160, height: 160)
                            .background(Color(red: 0.5, green: 0.5, blue: 0.5).opacity(0.3))
                            .cornerRadius(20)
                            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 2)
                            .overlay(
                                
                                ZStack {
                                    
                                    VStack(spacing: 15) {
                                        
                                        Image(systemName: "folder.fill.badge.plus")
                                            .font(.system(size: 50, weight: .bold))
                                        
                                        Text("Upload Files")
                                        
                                    }
                                    
                                    RoundedRectangle(cornerRadius: 20)
                                        .inset(by: 0.7)
                                        .stroke(
                                            LinearGradient(
                                                colors: [.white.opacity(0.4), .white.opacity(0.05)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1.4
                                        )
                                }
                            )
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        
                    } label: {
                        Rectangle()
                            .foregroundColor(.clear)
                            .frame(width: 160, height: 160)
                            .background(Color(red: 0.5, green: 0.5, blue: 0.5).opacity(0.3))
                            .cornerRadius(20)
                            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 2)
                            .overlay(
                                
                                ZStack {
                                    
                                    VStack(spacing: 15) {
                                        
                                        Image(systemName: "video.fill")
                                            .font(.system(size: 50, weight: .bold))
                                        
                                        Text("Start meeting")
                                        
                                    }
                                    
                                    RoundedRectangle(cornerRadius: 20)
                                        .inset(by: 0.7)
                                        .stroke(
                                            LinearGradient(
                                                colors: [.white.opacity(0.4), .white.opacity(0.05)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1.4
                                        )
                                }
                            )
                    }
                    .buttonStyle(.plain)
                }
                
                HStack(spacing: 40) {
                    
                    Button {
                        
                    } label: {
                        Rectangle()
                            .foregroundColor(.clear)
                            .frame(width: 160, height: 160)
                            .background(Color(red: 0.5, green: 0.5, blue: 0.5).opacity(0.3))
                            .cornerRadius(20)
                            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 2)
                            .overlay(
                                
                                ZStack {
                                    
                                    VStack(spacing: 15) {
                                        
                                        Image(systemName: "document.on.document.fill")
                                            .font(.system(size: 50, weight: .bold))
                                        
                                        Text("Captures")
                                        
                                    }
                                    
                                    RoundedRectangle(cornerRadius: 20)
                                        .inset(by: 0.7)
                                        .stroke(
                                            LinearGradient(
                                                colors: [.white.opacity(0.4), .white.opacity(0.05)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1.4
                                        )
                                }
                            )
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        
                    } label: {
                        Rectangle()
                            .foregroundColor(.clear)
                            .frame(width: 160, height: 160)
                            .background(Color(red: 0.5, green: 0.5, blue: 0.5).opacity(0.3))
                            .cornerRadius(20)
                            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 2)
                            .overlay(
                                
                                ZStack {
                                    
                                    VStack(spacing: 15) {
                                        
                                        Image(systemName: "eye.circle.fill")
                                            .font(.system(size: 50, weight: .bold))
                                     
                                        Text("DICOM viewer")
                                    }
                                    
                                    RoundedRectangle(cornerRadius: 20)
                                        .inset(by: 0.7)
                                        .stroke(
                                            LinearGradient(
                                                colors: [.white.opacity(0.4), .white.opacity(0.05)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1.4
                                        )
                                }
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

#Preview(windowStyle: .automatic) {
    HomeView2()
}
