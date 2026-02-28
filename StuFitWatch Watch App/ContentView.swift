//
//  ContentView.swift
//  StuFitWatch Watch App
//
//  Created by Stuart Mitchell on 25/2/2026.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "applewatch.radiowaves.left.and.right")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("StuFit Watch")
            Text("Waiting for rest cues")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
