//
//  StuFitWatchApp.swift
//  StuFitWatch Watch App
//
//  Created by Stuart Mitchell on 25/2/2026.
//

import SwiftUI

@main
struct StuFitWatch_Watch_AppApp: App {
    init() {
        WatchCueReceiver.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
