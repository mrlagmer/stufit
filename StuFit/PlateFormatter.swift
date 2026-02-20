//
//  PlateFormatter.swift
//  FullFitness
//
//  Created by Copilot on 31/1/2026.
//

import Foundation

/// Format plate array into readable string
func formatPlates(_ plates: [Double]) -> String {
    guard !plates.isEmpty else { return "Bar only" }
    
    var plateCount: [Double: Int] = [:]
    for plate in plates {
        plateCount[plate, default: 0] += 1
    }
    
    let formatted = plateCount
        .sorted { $0.key > $1.key }
        .map { plate, count in
            let plateString = plate == Double(Int(plate)) ? String(Int(plate)) : String(plate)
            return plateString + (count > 1 ? " ×\(count)" : "")
        }
        .joined(separator: " + ")
    
    return "Per side: \(formatted)"
}
