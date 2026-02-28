//
//  WatchCueReceiver.swift
//  StuFitWatch Watch App
//
//  Created by Copilot on 25/2/2026.
//

import Foundation
import WatchConnectivity
#if canImport(WatchKit)
import WatchKit
#endif
#if canImport(UIKit)
import UIKit
#endif

final class WatchCueReceiver: NSObject, WCSessionDelegate {
    static let shared = WatchCueReceiver()

    private override init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error {
            print("WatchConnectivity activation failed: \(error.localizedDescription)")
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        handle(payload: message)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        handle(payload: userInfo)
    }

#if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
#endif

    private func handle(payload: [String: Any]) {
        guard let type = payload["type"] as? String,
              type == "restCue",
              let cue = payload["cue"] as? String else {
            return
        }

        DispatchQueue.main.async {
            switch cue {
            case "tMinus10":
                self.playHapticTMinus10()
            case "restComplete":
                self.playHapticRestComplete()
            default:
                break
            }
        }
    }

    private func playHapticTMinus10() {
#if canImport(WatchKit)
        WKInterfaceDevice.current().play(.directionUp)
#endif
    }

    private func playHapticRestComplete() {
#if canImport(WatchKit)
        WKInterfaceDevice.current().play(.notification)
#endif
    }
}
