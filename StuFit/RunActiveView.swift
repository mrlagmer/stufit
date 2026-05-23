//
//  RunActiveView.swift
//  FullFitness
//
//  The "Run In Progress" screen, built from the StuFit Run Active design:
//  total time as the hero, current-km pace emphasised over overall pace,
//  distance progress, live heart rate, an optional route preview, per-km
//  splits, and floating lap / pause / stop controls.
//

import SwiftUI

// MARK: - Formatting helpers

enum RunFormat {
    /// Seconds → "M:SS" pace string.
    static func pace(_ secPerKm: Int) -> String {
        let m = secPerKm / 60
        let s = secPerKm % 60
        return "\(m):" + String(format: "%02d", s)
    }

    /// Seconds → "H:MM:SS" or "MM:SS".
    static func time(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return "\(h):" + String(format: "%02d:%02d", m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    static func km(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
    }
}

// MARK: - Run Active screen

struct RunActiveView: View {
    @ObservedObject var manager: RunSessionManager
    var onHide: () -> Void = {}
    var onFinish: () -> Void = {}

    @State private var showingStopConfirm = false

    private var accent: Color { .accentColor }
    private var cardBackground: Color { Color(.secondarySystemGroupedBackground) }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(.systemGroupedBackground).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    RunHeader(
                        accent: accent,
                        title: manager.goalLabel,
                        gpsLabel: manager.gpsStrength.label,
                        showGPS: manager.outdoor,
                        onHide: onHide
                    )

                    heroTime

                    paceDuoCard

                    heartRateCard

                    if manager.outdoor {
                        RunMapPreview(accent: accent)
                            .padding(.horizontal, 20)
                            .padding(.top, 14)
                    }

                    if !manager.splits.isEmpty || manager.distanceKm > 0 {
                        RunSplitsCard(
                            splits: manager.splits,
                            currentKm: manager.splits.count + 1,
                            accent: accent
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 14)
                    }
                }
                .padding(.bottom, 170)
            }

            controls
        }
        .navigationBarHidden(true)
        .confirmationDialog("End this run?", isPresented: $showingStopConfirm, titleVisibility: .visible) {
            Button("End run", role: .destructive) {
                manager.stop()
                onFinish()
            }
            Button("Keep running", role: .cancel) {}
        }
        .onAppear {
            if !manager.isActive { manager.start() }
        }
    }

    // MARK: Hero total time + progress

    private var heroTime: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("TOTAL TIME")
                .font(.system(size: 12, weight: .semibold))
                .tracking(0.6)
                .foregroundColor(.secondary)

            Text(RunFormat.time(manager.elapsed))
                .font(.system(size: 82, weight: .bold))
                .monospacedDigit()
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.top, 2)

            if let goalKm = manager.goalKm {
                progressBar(goalKm: goalKm)
                    .padding(.top, 16)
            } else {
                Text("\(String(format: "%.2f", manager.distanceKm)) km")
                    .font(.system(size: 15, weight: .semibold))
                    .monospacedDigit()
                    .padding(.top, 12)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
    }

    private func progressBar(goalKm: Double) -> some View {
        let pct = min(1.0, manager.distanceKm / goalKm)
        let remaining = max(0, goalKm - manager.distanceKm)
        return VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(String(format: "%.2f", manager.distanceKm)) km")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
                Text("\(String(format: "%.2f", remaining)) km to go")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .monospacedDigit()

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.tertiarySystemFill))
                    Capsule().fill(accent)
                        .frame(width: geo.size.width * pct)
                }
            }
            .frame(height: 6)

            HStack {
                Text("0")
                Spacer()
                Text(RunFormat.km(goalKm / 2))
                Spacer()
                Text("\(RunFormat.km(goalKm)) km")
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(Color(.tertiaryLabel))
            .monospacedDigit()
        }
    }

    // MARK: Pace duo card

    private var paceDuoCard: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("CURRENT KM PACE")
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(0.5)
                        .foregroundColor(.secondary)
                    Spacer()
                    trendChip
                }
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(manager.currentKmPaceSec.map(RunFormat.pace) ?? "--:--")
                        .font(.system(size: 44, weight: .bold))
                        .monospacedDigit()
                        .foregroundColor(.primary)
                    Text("/km")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider().padding(.horizontal, 16)

            HStack {
                Text("Overall pace")
                    .font(.system(size: 15, weight: .medium))
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(manager.overallPaceSec.map(RunFormat.pace) ?? "--:--")
                        .font(.system(size: 22, weight: .semibold))
                        .monospacedDigit()
                    Text("/km")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }

    @ViewBuilder
    private var trendChip: some View {
        if let current = manager.currentKmPaceSec, let overall = manager.overallPaceSec {
            let delta = current - overall
            if abs(delta) < 3 {
                Text("on pace")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
            } else {
                let slower = delta > 0
                HStack(spacing: 4) {
                    Image(systemName: slower ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                        .font(.system(size: 8))
                    Text("\(slower ? "+" : "−")\(RunFormat.pace(abs(delta))) vs avg")
                        .monospacedDigit()
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(slower ? Color(red: 1, green: 0.27, blue: 0.23)
                                        : Color(red: 0.19, green: 0.69, blue: 0.31))
            }
        }
    }

    // MARK: Heart-rate card

    private var heartRateCard: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "heart.fill")
                    .foregroundColor(Color(red: 1, green: 0.27, blue: 0.23))
                    .font(.system(size: 15))
                Text("HEART RATE")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(0.5)
                    .foregroundColor(.secondary)
            }
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(manager.heartRate.map { "\(Int($0.rounded()))" } ?? "--")
                    .font(.system(size: 28, weight: .bold))
                    .monospacedDigit()
                    .foregroundColor(Color(red: 1, green: 0.27, blue: 0.23))
                Text("bpm")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 20)
        .padding(.top, 14)
    }

    // MARK: Floating controls

    private var controls: some View {
        HStack(spacing: 36) {
            secondaryButton(systemName: "arrow.triangle.2.circlepath") {}

            Button(action: { manager.togglePause() }) {
                Image(systemName: manager.paused ? "play.fill" : "pause.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 84, height: 84)
                    .background(manager.paused ? Color(red: 0.19, green: 0.69, blue: 0.31) : accent)
                    .clipShape(Circle())
                    .shadow(color: (manager.paused ? Color(red: 0.19, green: 0.69, blue: 0.31) : accent).opacity(0.33),
                            radius: 11, x: 0, y: 8)
            }
            .buttonStyle(.plain)

            secondaryButton(systemName: "stop.fill") { showingStopConfirm = true }
        }
        .padding(.bottom, 30)
    }

    private func secondaryButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.primary)
                .frame(width: 56, height: 56)
                .background(cardBackground)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Header

private struct RunHeader: View {
    let accent: Color
    let title: String
    let gpsLabel: String
    let showGPS: Bool
    var onHide: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button(action: onHide) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Hide")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .foregroundColor(accent)
                }
                .buttonStyle(.plain)

                Spacer()

                HStack(spacing: 6) {
                    Circle()
                        .fill(accent)
                        .frame(width: 6, height: 6)
                    Text("LIVE")
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(0.2)
                }
                .foregroundColor(accent)
                .padding(.vertical, 4)
                .padding(.horizontal, 10)
                .background(accent.opacity(0.1))
                .clipShape(Capsule())

                Spacer()

                if showGPS {
                    HStack(spacing: 5) {
                        gpsDots
                        Text(gpsLabel)
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.secondary)
                } else {
                    Text(gpsLabel)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            .frame(minHeight: 32)

            Text(title)
                .font(.system(size: 22, weight: .semibold))
                .padding(.top, 6)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var gpsDots: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<3) { i in
                Capsule()
                    .fill(accent.opacity(0.5 + Double(i) * 0.25))
                    .frame(width: 3, height: CGFloat(6 + i * 3))
            }
        }
    }
}

// MARK: - Splits

private struct RunSplitsCard: View {
    let splits: [RunSessionManager.Split]
    let currentKm: Int
    let accent: Color

    var body: some View {
        let fastest = splits.map(\.seconds).min() ?? 0
        let slowest = splits.map(\.seconds).max() ?? 1
        let range = max(1, slowest - fastest)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("SPLITS")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(0.5)
                    .foregroundColor(.secondary)
                Spacer()
                Text("auto every km")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(.tertiaryLabel))
            }

            VStack(spacing: 8) {
                ForEach(splits) { split in
                    let isFastest = split.seconds == fastest
                    let fraction = 0.25 + (Double(slowest - split.seconds) / Double(range)) * 0.6
                    HStack(spacing: 10) {
                        Text("\(split.km)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                            .frame(width: 28, alignment: .leading)
                            .monospacedDigit()

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color(.tertiarySystemFill))
                                Capsule()
                                    .fill(isFastest ? accent : Color(.label).opacity(0.45))
                                    .frame(width: geo.size.width * fraction)
                            }
                        }
                        .frame(height: 6)

                        Text(RunFormat.pace(split.seconds))
                            .font(.system(size: 14, weight: .semibold))
                            .monospacedDigit()
                            .foregroundColor(isFastest ? accent : .primary)
                            .frame(width: 56, alignment: .trailing)
                    }
                }

                // Current km, in progress
                HStack(spacing: 10) {
                    Text("\(currentKm)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(accent)
                        .frame(width: 28, alignment: .leading)
                        .monospacedDigit()
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color(.tertiarySystemFill))
                            Capsule().fill(accent.opacity(0.35))
                                .frame(width: geo.size.width * 0.35)
                        }
                    }
                    .frame(height: 6)
                    Text("· · ·")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 56, alignment: .trailing)
                }
                .opacity(0.7)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Map preview placeholder

private struct RunMapPreview: View {
    let accent: Color

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color(red: 0.90, green: 0.91, blue: 0.93)
            GeometryReader { geo in
                Path { path in
                    let w = geo.size.width, h = geo.size.height
                    path.move(to: CGPoint(x: 0.05 * w, y: 0.75 * h))
                    path.addCurve(to: CGPoint(x: 0.56 * w, y: 0.62 * h),
                                  control1: CGPoint(x: 0.25 * w, y: 0.55 * h),
                                  control2: CGPoint(x: 0.40 * w, y: 0.80 * h))
                    path.addCurve(to: CGPoint(x: 0.95 * w, y: 0.30 * h),
                                  control1: CGPoint(x: 0.75 * w, y: 0.30 * h),
                                  control2: CGPoint(x: 0.85 * w, y: 0.40 * h))
                }
                .stroke(accent, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
            }
            HStack(spacing: 4) {
                Circle().fill(accent).frame(width: 8, height: 8)
                Text("Live route")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.primary)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(Color(.systemBackground).opacity(0.92))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(8)
        }
        .frame(height: 96)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
