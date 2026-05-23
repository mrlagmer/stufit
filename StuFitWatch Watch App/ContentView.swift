//
//  ContentView.swift
//  StuFitWatch Watch App
//
//  Created by Stuart Mitchell on 25/2/2026.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var watchSessionManager: WatchSessionManager
    
    var body: some View {
        if watchSessionManager.isRunSession {
            WatchRunSessionView()
        } else if watchSessionManager.workoutName.isEmpty {
            VStack {
                Image(systemName: "applewatch.radiowaves.left.and.right")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                Text("StuFit Watch")
                Text("Waiting for workout")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .onAppear {
                watchSessionManager.activate()
            }
        } else {
            WatchWorkoutSessionView()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(WatchSessionManager.shared)
}
