//
//  DemoDICOMmacApp.swift
//  DemoDICOMmac
//
//  Created by Igor Tarantino on 08/05/2026.
//

import SwiftUI

@main
struct DemoDICOMmacApp: App {
    @State private var store = FolderStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
    }
}
