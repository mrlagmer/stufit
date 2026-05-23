//
//  WatchRunSessionView.swift
//  StuFitWatch Watch App
//
//  Active-run companion face built from the StuFit Run Active design:
//  total time hero, current-km vs average pace, live heart rate, and
//  distance. Tap to toggle between the stacked and grid layouts.
//

import SwiftUI

struct WatchRunSessionView: View {
    @EnvironmentObject private var session: WatchSessionManager
    @State private var useGrid = false

    private let hrColor = Color(red: 1, green: 0.27, blue: 0.23)

    var body: some View {
        Group {
            if useGrid { gridLayout } else { stackedLayout }
        }
        .background(Color.black.ignoresSafeArea())
        .onTapGesture { useGrid.toggle() }
    }

    // MARK: - Stacked layout

    private var stackedLayout: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 4) {
                    Circle().fill(Color.accentColor).frame(width: 5, height: 5)
                    Text(goalTag)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.accentColor)
                }
                Spacer()
            }

            Spacer(minLength: 4)

            VStack(spacing: 1) {
                Text("TIME")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(.white.opacity(0.45))
                Text(timeString)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            HStack(alignment: .bottom) {
                paceMetric(label: "CURR KM", value: paceString(session.runCurrentKmPaceSec), color: .accentColor)
                Spacer()
                paceMetric(label: "AVG", value: paceString(session.runAveragePaceSec), color: .white, alignTrailing: true)
            }

            Spacer(minLength: 6)

            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "heart.fill").font(.system(size: 10)).foregroundColor(hrColor)
                    Text("HEART")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                }
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(hrString).font(.system(size: 18, weight: .bold, design: .rounded))
                        .monospacedDigit().foregroundColor(hrColor)
                    Text("bpm").font(.system(size: 8, weight: .semibold)).foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(hrColor.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Spacer(minLength: 6)

            VStack(spacing: 1) {
                Text("DISTANCE")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(String(format: "%.2f", session.runDistanceKm))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .monospacedDigit().foregroundColor(.white)
                    Text("km").font(.system(size: 9, weight: .semibold)).foregroundColor(.white.opacity(0.55))
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func paceMetric(label: String, value: String, color: Color, alignTrailing: Bool = false) -> some View {
        VStack(alignment: alignTrailing ? .trailing : .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.white.opacity(0.55))
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: alignTrailing ? 17 : 22, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(color)
                Text("/km").font(.system(size: 9, weight: .semibold)).foregroundColor(.white.opacity(0.55))
            }
        }
    }

    // MARK: - Grid layout

    private var gridLayout: some View {
        VStack(spacing: 6) {
            HStack {
                HStack(spacing: 4) {
                    Circle().fill(Color.accentColor).frame(width: 5, height: 5)
                    Text(goalTag).font(.system(size: 9, weight: .bold)).foregroundColor(.accentColor)
                }
                Spacer()
            }
            VStack(spacing: 4) {
                gridCell(label: "TIME", value: timeString, color: .white, background: Color.white.opacity(0.05))
                HStack(spacing: 4) {
                    gridCell(label: "CURR KM", value: paceString(session.runCurrentKmPaceSec), unit: "/km",
                             color: .accentColor, background: Color.accentColor.opacity(0.18))
                    gridCell(label: "AVG", value: paceString(session.runAveragePaceSec), unit: "/km",
                             color: .white, background: Color.white.opacity(0.05))
                }
                HStack(spacing: 4) {
                    gridCell(label: "DIST", value: String(format: "%.2f", session.runDistanceKm), unit: "km",
                             color: .white, background: Color.white.opacity(0.05))
                    gridCell(label: "HEART", value: hrString, unit: "bpm",
                             color: hrColor, background: hrColor.opacity(0.14))
                }
            }
        }
        .padding(8)
    }

    private func gridCell(label: String, value: String, unit: String? = nil, color: Color, background: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 8, weight: .semibold)).foregroundColor(.white.opacity(0.5))
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(.system(size: 20, weight: .bold, design: .rounded))
                    .monospacedDigit().foregroundColor(color).minimumScaleFactor(0.7).lineLimit(1)
                if let unit {
                    Text(unit).font(.system(size: 8, weight: .semibold)).foregroundColor(.white.opacity(0.5))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Helpers

    private var goalTag: String {
        if let goal = session.runGoalKm {
            let n = goal == goal.rounded() ? String(Int(goal)) : String(format: "%.1f", goal)
            return "\(n)K"
        }
        return "RUN"
    }

    private var timeString: String {
        let total = Int(session.elapsedTime)
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }

    private func paceString(_ sec: Int?) -> String {
        guard let sec else { return "--:--" }
        return "\(sec / 60):" + String(format: "%02d", sec % 60)
    }

    private var hrString: String {
        guard let hr = session.currentHeartRate else { return "--" }
        return "\(Int(hr.rounded()))"
    }
}

#Preview {
    WatchRunSessionView()
        .environmentObject(WatchSessionManager.shared)
}
