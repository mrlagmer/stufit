//
//  WatchRestCue.swift
//  FullFitness
//
//  Created by Copilot on 25/2/2026.
//

import Foundation

enum WatchRestCue: String {
    case tMinus10
    case restComplete

    static let messageTypeKey = "type"
    static let restCueTypeValue = "restCue"
    static let cueKey = "cue"

    var payload: [String: Any] {
        [
            Self.messageTypeKey: Self.restCueTypeValue,
            Self.cueKey: rawValue
        ]
    }
}
