//
//  HomeView3.swift
//  DemoDICOM
//
//  Created by Igor Tarantino on 21/05/2026.
//

import SwiftUI

struct HomeView3: View {
    
    var body: some View {
        
        ScrollView {
            
            VStack(alignment: .leading) {
                
                HStack {
                    Text("Welcome to ATRIA")
                        .font(.largeTitle)
                    
                    Spacer()
                }
                .padding(50)
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("Pre - Op meeting")
                            .font(.title)
                        Text("Description of the subtitle under the preop meeting text.")
                            .font(.callout)
                            .padding(.bottom)
                        Button {
                            
                        } label: {
                            HStack {
                                Image(systemName: "video.fill")
                                Text("Start meeting")
                            }
                        }
                    }
                    .frame(width: 250)
                    
                    Spacer()
                    
                    Rectangle()
                        .frame(width: 250, height: 150)
                }
                .padding(50)
            }
        }
    }
}

#Preview(windowStyle: .automatic) {
    HomeView3()
}
