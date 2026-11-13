//
//  SDA_Church_FinderApp.swift
//  AdventFind
//
//  Created by Kyle Slingo on 2/10/26.
//

import SwiftUI

@main
struct SDA_Church_FinderApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
                .applyTextSize()
                .applyHighContrast()
                .task {
                    DirectorySyncService.shared.seedCacheFromBundleIfNeeded()
                    await DirectorySyncService.shared.sync()
                }
        }
    }
}
