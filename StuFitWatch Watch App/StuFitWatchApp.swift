//
//  StuFitWatchApp.swift
//  StuFitWatch Watch App
//
//  Created by Stuart Mitchell on 25/2/2026.
//

import SwiftUI

@main
struct StuFitWatch_Watch_AppApp: App {
    @StateObject private var watchSessionManager = WatchSessionManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(watchSessionManager)
        }
    }
}
