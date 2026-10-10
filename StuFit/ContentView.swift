//
//  ContentView.swift
//  FullFitness
//
//  Created by Stuart Mitchell on 27/1/2026.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        HomeView()
            .preferredColorScheme(.dark)
            .tint(GLM.purple)
    }
}

#Preview {
    ContentView()
}
