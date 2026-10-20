//
//  HomeView.swift
//  FullFitness
//
//  Created by Copilot on 27/1/2026.
//

import SwiftUI

/// A trainer-built weights session, carried through navigation.
struct TrainerWeightsSession: Hashable {
    let id = UUID()
    let workout: ProgramWorkout
    let restSeconds: Int
    let warmupRestSeconds: Int
    let cues: [String: String]

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

private enum HomeRoute: Hashable {
    case checkIn
    case weights(TrainerWeightsSession)
    case history
    case settings
}

struct HomeView: View {
    @StateObject private var healthStore = HealthStore()
    @State private var path: [HomeRoute] = []
    @State private var showingDeloadFromBanner = false
    @State private var runManager: RunSessionManager?
    @State private var showingRunActive = false

    private func startCardio(_ plan: CardioPlan) {
        runManager = RunSessionManager(
            goal: plan.goal,
            outdoor: plan.outdoor,
            activity: plan.activity,
            coachCues: plan.cues,
            healthStore: healthStore
        )
        path = []
        showingRunActive = true
    }

    private func finishRun() {
        runManager?.stop()
        runManager = nil
        showingRunActive = false
    }

    var body: some View {
        NavigationStack(path: $path) {
            homeScreen
                .glmScreen()
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: HomeRoute.self) { route in
                    destination(route)
                }
        }
        .sheet(isPresented: $showingDeloadFromBanner) {
            DeloadOptionsView(isPresented: $showingDeloadFromBanner, healthStore: healthStore)
        }
        .fullScreenCover(isPresented: $showingRunActive) {
            if let runManager {
                RunActiveView(
                    manager: runManager,
                    onHide: { showingRunActive = false },
                    onFinish: finishRun
                )
            }
        }
    }

    @ViewBuilder
    private func destination(_ route: HomeRoute) -> some View {
        switch route {
        case .checkIn:
            TrainerCheckInView(
                healthStore: healthStore,
                onBack: { path = [] },
                onStartWeights: { workout, rest, warmupRest, cues in
                    let session = TrainerWeightsSession(
                        workout: workout,
                        restSeconds: rest,
                        warmupRestSeconds: warmupRest,
                        cues: cues
                    )
                    // Replace the check-in so finishing returns straight home.
                    path = [.weights(session)]
                },
                onStartCardio: startCardio
            )
        case .weights(let session):
            WorkoutSessionView(
                healthStore: healthStore,
                workout: session.workout,
                restDuration: TimeInterval(session.restSeconds),
                warmupRestDuration: TimeInterval(session.warmupRestSeconds),
                coachingCues: session.cues
            )
        case .history:
            WorkoutHistoryView(healthStore: healthStore)
        case .settings:
            TrainerSettingsView(healthStore: healthStore)
        }
    }

    // MARK: - Home

    private var homeScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GLM.Space.cardGap) {
                greetingHeader

                if !healthStore.authorized {
                    connectHealthCard
                }

                if let runManager, runManager.isActive, !showingRunActive {
                    resumeRunCard(runManager)
                }

                trainerCard

                if healthStore.authorized && healthStore.shouldShowDeloadBanner {
                    deloadCard
                }

                if !healthStore.workoutSessionRecords.isEmpty {
                    ProgressSummaryCard(healthStore: healthStore)
                    lastSessionCard
                }
            }
            .padding(.horizontal, GLM.Space.gutter)
            .padding(.top, 14)
            .padding(.bottom, 32)
        }
    }

    private var greetingHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 7) {
                Text(GLMFormat.greeting).glmText(.greeting)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                HStack(spacing: 7) {
                    Circle().fill(GLM.purple).frame(width: 6, height: 6)
                    Text(streakLine).glmText(.body)
                }
            }
            Spacer()
            HStack(spacing: 8) {
                headerButton(systemImage: "clock.arrow.circlepath", label: "History") { path.append(.history) }
                headerButton(systemImage: "gearshape", label: "Settings") { path.append(.settings) }
            }
        }
        .padding(.bottom, 2)
    }

    private func headerButton(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(GLM.inkMuted)
                .frame(width: 40, height: 40)
                .background(GLM.surface)
                .overlay { Circle().strokeBorder(GLM.border, lineWidth: 1) }
                .clipShape(Circle())
        }
        .buttonStyle(.glmPress)
        .accessibilityLabel(label)
    }

    private var streakLine: String {
        guard !healthStore.workoutSessionRecords.isEmpty else {
            return "Ready when you are"
        }
        switch healthStore.weeklyStreak {
        case 0: return "No streak yet · start one this week"
        case 1: return "1-week streak"
        case let streak: return "\(streak)-week streak"
        }
    }

    private var trainerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                GLMIconTile(glyph: "🧑‍🏫", size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Train with your coach").glmText(.cardTitle)
                    Text(trainerSubtitle).glmText(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Button("Start a session") { path.append(.checkIn) }
                .buttonStyle(.glmPrimary)
                .disabled(runManager?.isActive == true)
        }
        .glmCard(.featured)
    }

    private var trainerSubtitle: String {
        guard let last = TrainerContext.lastSession(healthStore) else {
            return "Tell me how long you've got and I'll build today's plan."
        }
        return "Last session \(TrainerContext.relativeDay(last.endDate)). I'll plan today around it."
    }

    private var connectHealthCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                GLMIconTile(glyph: "❤️")
                VStack(alignment: .leading, spacing: 2) {
                    Text("Connect Health").glmText(.rowTitle)
                    Text("Reads workouts and heart rate so your coach can plan around them.")
                        .glmText(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Button("Allow Health access") { healthStore.requestAuthorization() }
                .buttonStyle(.glmSoft)
                .padding(.top, 4)
        }
        .glmCard()
    }

    private var deloadCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                GLMIconTile(glyph: "🌅")
                VStack(alignment: .leading, spacing: 2) {
                    Text("Welcome back").glmText(.rowTitle)
                    Text("Over a week since your last session. Dropping the weights eases you back in safely.")
                        .glmText(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Button("Deload weights") { showingDeloadFromBanner = true }
                .buttonStyle(.glmSoft)
                .padding(.top, 4)
        }
        .glmCard()
    }

    @ViewBuilder
    private var lastSessionCard: some View {
        if let last = TrainerContext.lastSession(healthStore) {
            Button(action: { path.append(.history) }) {
                HStack(spacing: 13) {
                    GLMIconTile(glyph: last.kind.glyph)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Last session").glmText(.label)
                        Text(TrainerContext.describe(last)).glmText(.rowTitle)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(GLM.inkMuted)
                }
                .glmRow()
            }
            .buttonStyle(.glmPress)
        }
    }

    private func resumeRunCard(_ manager: RunSessionManager) -> some View {
        Button(action: { showingRunActive = true }) {
            HStack(spacing: 14) {
                GLMIconTile(glyph: manager.activity.sessionKind.glyph, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(manager.activity == .walk ? "Walk" : "Run") in progress").glmText(.cardTitle)
                    Text(RunFormat.time(manager.elapsed)).glmText(.readout)
                }
                Spacer()
                Text("Resume").glmText(.rowValue, color: GLM.purple)
            }
            .glmCard(.featured, padding: EdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 18))
        }
        .buttonStyle(.glmPress)
    }
}

/// Animated typing indicator dots
struct TypingIndicator: View {
    @State private var animationPhase = 0

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(GLM.inkMuted)
                    .frame(width: 5, height: 5)
                    .opacity(animationPhase == index ? 1.0 : 0.3)
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(400))
                withAnimation(.easeInOut(duration: 0.2)) {
                    animationPhase = (animationPhase + 1) % 3
                }
            }
        }
    }
}

#Preview {
    HomeView()
}
