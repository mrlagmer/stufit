//
//  RunActiveView.swift
//  FullFitness
//
//  The "Run In Progress" screen: total time as the hero, current-km pace
//  emphasised over overall pace, distance progress, live heart rate, an
//  optional route preview, per-km splits, and floating pause / stop controls.
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

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    RunHeader(
                        title: manager.goalLabel,
                        gpsLabel: manager.gpsStrength.label,
                        showGPS: manager.outdoor,
                        onHide: onHide
                    )

                    heroTime

                    paceDuoCard

                    heartRateCard

                    if manager.outdoor {
                        RunMapPreview()
                            .padding(.horizontal, GLM.Space.gutter)
                            .padding(.top, GLM.Space.cardGap)
                    }

                    if !manager.splits.isEmpty || manager.distanceKm > 0 {
                        RunSplitsCard(
                            splits: manager.splits,
                            currentKm: manager.splits.count + 1
                        )
                        .padding(.horizontal, GLM.Space.gutter)
                        .padding(.top, GLM.Space.cardGap)
                    }
                }
                .padding(.bottom, 170)
            }

            controls
        }
        .glmScreen()
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
            Text("Total time").glmEyebrow()

            Text(RunFormat.time(manager.elapsed))
                .font(.system(size: 64, weight: .bold))
                .tracking(-1.28)
                .monospacedDigit()
                .foregroundColor(GLM.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.top, 4)

            if let goalKm = manager.goalKm {
                progressBar(goalKm: goalKm)
                    .padding(.top, 16)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(String(format: "%.2f", manager.distanceKm)).glmText(.rowValue)
                    Text("km").glmText(.unit)
                }
                .padding(.top, 12)
            }
        }
        .padding(.horizontal, GLM.Space.gutter)
        .padding(.top, 14)
    }

    private func progressBar(goalKm: Double) -> some View {
        let pct = min(1.0, manager.distanceKm / goalKm)
        let remaining = max(0, goalKm - manager.distanceKm)
        return VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(String(format: "%.2f", manager.distanceKm)).glmText(.rowValue)
                    Text("km").glmText(.unit)
                }
                Spacer()
                Text("\(String(format: "%.2f", remaining)) km to go").glmText(.readout)
            }

            GLMMetricBar(fraction: pct, color: GLM.cyan, height: 6)

            HStack {
                Text("0")
                Spacer()
                Text(RunFormat.km(goalKm / 2))
                Spacer()
                Text("\(RunFormat.km(goalKm)) km")
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(GLM.inkFaint)
            .monospacedDigit()
        }
    }

    // MARK: Pace duo card

    private var paceDuoCard: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Current km pace").glmEyebrow()
                    Spacer()
                    trendChip
                }
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(manager.currentKmPaceSec.map(RunFormat.pace) ?? "--:--")
                        .glmText(.metricLarge)
                    Text("/km").glmText(.unit)
                }
            }
            .padding(.horizontal, GLM.Space.cardPadX)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)

            GLMHairline().padding(.horizontal, GLM.Space.cardPadX)

            HStack {
                Text("Overall pace").glmText(.cardTitle)
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(manager.overallPaceSec.map(RunFormat.pace) ?? "--:--")
                        .glmText(.statValue)
                    Text("/km").glmText(.unit)
                }
            }
            .padding(.horizontal, GLM.Space.cardPadX)
            .padding(.vertical, 14)
        }
        .background(GLM.surface)
        .clipShape(RoundedRectangle(cornerRadius: GLM.Radius.card, style: .continuous))
        .padding(.horizontal, GLM.Space.gutter)
        .padding(.top, 20)
    }

    @ViewBuilder
    private var trendChip: some View {
        if let current = manager.currentKmPaceSec, let overall = manager.overallPaceSec {
            let delta = current - overall
            if abs(delta) < 3 {
                GLMTag(text: "On pace", color: GLM.inkMuted)
            } else {
                let slower = delta > 0
                GLMTag(
                    text: "\(slower ? "+" : "−")\(RunFormat.pace(abs(delta))) vs avg",
                    color: slower ? GLM.atRisk : GLM.success,
                    dot: true
                )
            }
        }
    }

    // MARK: Heart-rate card

    private var heartRateCard: some View {
        HStack(spacing: 12) {
            GLMIconTile(glyph: "❤️", size: 38)
            Text("Heart rate").glmText(.cardTitle)
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(manager.heartRate.map { "\(Int($0.rounded()))" } ?? "--")
                    .glmText(.metric, color: GLM.cyan)
                Text("bpm").glmText(.unit)
            }
        }
        .glmCard(padding: EdgeInsets(top: 14, leading: 18, bottom: 14, trailing: 20))
        .padding(.horizontal, GLM.Space.gutter)
        .padding(.top, GLM.Space.cardGap)
    }

    // MARK: Floating controls

    private var controls: some View {
        HStack(spacing: 36) {
            secondaryButton(systemName: "arrow.triangle.2.circlepath") {}

            Button(action: { manager.togglePause() }) {
                Image(systemName: manager.paused ? "play.fill" : "pause.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(GLM.onAccent)
                    .frame(width: 84, height: 84)
                    .background(manager.paused ? GLM.green : GLM.purple)
                    .clipShape(Circle())
            }
            .buttonStyle(.glmPress)

            secondaryButton(systemName: "stop.fill") { showingStopConfirm = true }
        }
        .padding(.bottom, 30)
    }

    private func secondaryButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(GLM.ink)
                .frame(width: 56, height: 56)
                .background(GLM.surface)
                .overlay { Circle().strokeBorder(GLM.border, lineWidth: 1) }
                .clipShape(Circle())
        }
        .buttonStyle(.glmPress)
    }
}

// MARK: - Header

private struct RunHeader: View {
    let title: String
    let gpsLabel: String
    let showGPS: Bool
    var onHide: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button(action: onHide) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Hide")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(GLM.purple)
                }
                .buttonStyle(.glmPress)

                Spacer()

                GLMTag(text: "Live", color: GLM.purple, dot: true)

                Spacer()

                HStack(spacing: 5) {
                    if showGPS { gpsDots }
                    Text(gpsLabel).glmText(.label)
                }
            }
            .frame(minHeight: 32)

            Text(title).glmText(.screenTitle)
                .padding(.top, 8)
        }
        .padding(.horizontal, GLM.Space.gutter)
        .padding(.top, 8)
    }

    private var gpsDots: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<3) { i in
                Capsule()
                    .fill(GLM.purple.opacity(0.5 + Double(i) * 0.25))
                    .frame(width: 3, height: CGFloat(6 + i * 3))
            }
        }
    }
}

// MARK: - Splits

private struct RunSplitsCard: View {
    let splits: [RunSessionManager.Split]
    let currentKm: Int

    var body: some View {
        let fastest = splits.map(\.seconds).min() ?? 0
        let slowest = splits.map(\.seconds).max() ?? 1
        let range = max(1, slowest - fastest)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Splits").glmEyebrow()
                Spacer()
                Text("auto every km").glmText(.caption, color: GLM.inkFaint)
            }

            VStack(spacing: 8) {
                ForEach(splits) { split in
                    let isFastest = split.seconds == fastest
                    let fraction = 0.25 + (Double(slowest - split.seconds) / Double(range)) * 0.6
                    HStack(spacing: 10) {
                        Text("\(split.km)")
                            .glmText(.readout)
                            .frame(width: 28, alignment: .leading)

                        GLMMetricBar(fraction: fraction, color: isFastest ? GLM.purple : GLM.inkMuted, height: 6)

                        Text(RunFormat.pace(split.seconds))
                            .glmText(.rowValue, color: isFastest ? GLM.purple : GLM.ink)
                            .frame(width: 56, alignment: .trailing)
                    }
                }

                // Current km, in progress
                HStack(spacing: 10) {
                    Text("\(currentKm)")
                        .glmText(.readout, color: GLM.purple)
                        .frame(width: 28, alignment: .leading)
                    GLMMetricBar(fraction: 0.35, color: GLM.purple.opacity(0.35), height: 6)
                    Text("· · ·")
                        .glmText(.readout)
                        .frame(width: 56, alignment: .trailing)
                }
            }
        }
        .glmCard(padding: EdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 18))
    }
}

// MARK: - Map preview placeholder

private struct RunMapPreview: View {
    var body: some View {
        ZStack(alignment: .topTrailing) {
            GLM.surface
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
                .stroke(GLM.cyan, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
            }
            GLMTag(text: "Live route", color: GLM.ink, dot: false)
                .padding(8)
        }
        .frame(height: 96)
        .clipShape(RoundedRectangle(cornerRadius: GLM.Radius.card, style: .continuous))
    }
}
