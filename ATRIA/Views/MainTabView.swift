//
//  MainTabView.swift
//  ATRIA
//

import SwiftUI

/// Root tab container shown once the SharePlay session has started (or in solo mode).
///
/// Uses `.sidebarAdaptable` which renders as a compact sidebar ornament on visionOS,
/// giving access to the DICOM viewer and the saved annotations library.
struct MainTabView: View {
    
    var body: some View {
        
        TabView {
            
            Tab("Home", systemImage: "house.fill") {
                HomeView()
            }
            
            Tab("Disclaimer", systemImage: "info.circle.text.page.fill") {
                DisclaimerView()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }
}
