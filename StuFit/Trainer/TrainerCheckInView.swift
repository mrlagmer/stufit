//
//  TrainerCheckInView.swift
//  StuFit
//
//  The start of every session: a short spoken chat with the trainer. They
//  ask how long you've got, weights or cardio, and how you feel, then build
//  today's plan from your history. Type anything to adjust the plan.
//

import SwiftUI

struct TrainerCheckInView: View {
    @ObservedObject var healthStore: HealthStore
    var onBack: () -> Void
    var onStartWeights: (_ workout: ProgramWorkout, _ restSeconds: Int, _ warmupRestSeconds: Int, _ cues: [String: String]) -> Void
    var onStartCardio: (CardioPlan) -> Void

    private enum Step {
        case time, focus, cardioType, feeling, building, plan
    }

    private struct Message: Identifiable {
        let id = UUID()
        let fromCoach: Bool
        let text: String
    }

    @AppStorage("trainerVoiceEnabled") private var voiceEnabled = true
    @State private var messages: [Message] = []
    @State private var step: Step = .time
    @State private var answers = TrainerAnswers()
    @State private var plan: TrainerPlan?
    @State private var replyText = ""
    @State private var speech = SpeechSynthesizerDelegate()
    @State private var planner = TrainerPlanner()
    @State private var hasStarted = false
    @FocusState private var replyFocused: Bool

    private let timeOptions = [20, 30, 45, 60, 90]
    private let feelingOptions = ["Fresh", "Normal", "Tired", "Sore"]

    var body: some View {
        VStack(spacing: 0) {
            GLMScreenHeader("Coach", subtitle: headerSubtitle, onBack: {
                speech.stopAndClearQueue()
                onBack()
            }) {
                Button {
                    voiceEnabled.toggle()
                    if !voiceEnabled { speech.stopAndClearQueue() }
                } label: {
                    Image(systemName: voiceEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(voiceEnabled ? GLM.purple : GLM.inkMuted)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.glmPress)
                .accessibilityLabel(voiceEnabled ? "Mute coach" : "Unmute coach")
            }

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: GLM.Space.listGap) {
                        ForEach(messages) { message in
                            bubble(message)
                        }
                        if step == .building {
                            HStack { TypingIndicator() }
                                .padding(.vertical, 14)
                                .padding(.horizontal, 16)
                                .background(GLM.surface)
                                .clipShape(RoundedRectangle(cornerRadius: GLM.Radius.cardSm, style: .continuous))
                        }
                        if step == .plan, let plan {
                            planCard(plan)
                                .padding(.top, 4)
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(.horizontal, GLM.Space.gutterTight)
                    .padding(.vertical, 16)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: messages.count) { scrollToBottom(proxy) }
                .onChange(of: step) { scrollToBottom(proxy) }
            }

            replyBar
        }
        .glmScreen()
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            guard !hasStarted else { return }
            hasStarted = true
            coachSays(TrainerContext.greeting(healthStore))
        }
        .onDisappear {
            speech.stopAndClearQueue()
        }
    }

    private var headerSubtitle: String {
        if let provider = plan?.provider { return "Planned with \(provider.label)" }
        if plan != nil { return "Program fallback" }
        return "Today's check-in"
    }

    // MARK: - Messages

    private func bubble(_ message: Message) -> some View {
        HStack {
            if !message.fromCoach { Spacer(minLength: 48) }
            Text(message.text)
                .font(.system(size: 14))
                .foregroundColor(message.fromCoach ? GLM.ink : GLM.onAccent)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 11)
                .padding(.horizontal, 14)
                .background(message.fromCoach ? GLM.surface : GLM.purple)
                .clipShape(RoundedRectangle(cornerRadius: GLM.Radius.cardSm, style: .continuous))
            if message.fromCoach { Spacer(minLength: 48) }
        }
        .frame(maxWidth: .infinity, alignment: message.fromCoach ? .leading : .trailing)
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
    }

    private func coachSays(_ text: String) {
        messages.append(Message(fromCoach: true, text: text))
        if voiceEnabled {
            speech.speakCoachLine(text)
        }
    }

    private func userSays(_ text: String) {
        messages.append(Message(fromCoach: false, text: text))
    }

    // MARK: - Reply bar

    private var replyBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            quickReplies
            if step == .feeling || step == .plan {
                HStack(spacing: 10) {
                    TextField(step == .plan ? "Ask for a change…" : "Anything I should know?", text: $replyText, axis: .vertical)
                        .lineLimit(1...3)
                        .font(.system(size: 14))
                        .foregroundColor(GLM.ink)
                        .focused($replyFocused)
                        .submitLabel(.send)
                        .onSubmit(submitReply)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .background(GLM.appBg)
                        .clipShape(RoundedRectangle(cornerRadius: GLM.Radius.field, style: .continuous))
                    Button(action: submitReply) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(GLM.onAccent)
                            .frame(width: 36, height: 36)
                            .background(replyText.isEmpty ? GLM.inkFaint : GLM.purple)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.glmPress)
                    .disabled(replyText.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityLabel("Send")
                }
            }
        }
        .padding(.horizontal, GLM.Space.gutterTight)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(GLM.sectionBg)
    }

    @ViewBuilder
    private var quickReplies: some View {
        switch step {
        case .time:
            chipRow(timeOptions.map { minutes in
                (minutes >= 90 ? "90+ min" : "\(minutes) min", { chooseTime(minutes) })
            })
        case .focus:
            chipRow([
                ("Weights", { chooseFocus(.weights) }),
                ("Cardio", { chooseFocus(.cardio) })
            ])
        case .cardioType:
            chipRow([
                ("Run outside", { chooseCardio(.run, outdoor: true) }),
                ("Treadmill run", { chooseCardio(.run, outdoor: false) }),
                ("Walk outside", { chooseCardio(.walk, outdoor: true) }),
                ("Treadmill walk", { chooseCardio(.walk, outdoor: false) })
            ])
        case .feeling:
            chipRow(feelingOptions.map { feeling in (feeling, { chooseFeeling(feeling) }) })
        case .plan:
            chipRow([
                ("Make it shorter", { requestChange("Make it shorter.") }),
                ("Push me harder", { requestChange("Push me harder today.") }),
                ("Something different", { requestChange("Give me something different.") })
            ])
        case .building:
            EmptyView()
        }
    }

    private func chipRow(_ options: [(String, () -> Void)]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(options.indices, id: \.self) { index in
                    GLMChip(title: options[index].0, action: options[index].1)
                }
            }
        }
    }

    // MARK: - Flow

    private func chooseTime(_ minutes: Int) {
        answers.minutes = minutes
        userSays(minutes >= 90 ? "90 minutes or more" : "\(minutes) minutes")
        let lean = TrainerContext.recommendedFocus(healthStore)
        coachSays("\(lean.reason) Weights or cardio today?")
        step = .focus
    }

    private func chooseFocus(_ focus: TrainingFocus) {
        answers.focus = focus
        userSays(focus == .weights ? "Weights" : "Cardio")
        if focus == .cardio {
            coachSays("Run or walk? And outside or on the treadmill?")
            step = .cardioType
        } else {
            askFeeling()
        }
    }

    private func chooseCardio(_ activity: CardioActivity, outdoor: Bool) {
        answers.cardioActivity = activity
        answers.outdoor = outdoor
        userSays("\(activity == .run ? "Run" : "Walk"), \(outdoor ? "outside" : "treadmill")")
        askFeeling()
    }

    private func askFeeling() {
        coachSays("How are you feeling? Anything sore, or anything I should know?")
        step = .feeling
    }

    private func chooseFeeling(_ feeling: String) {
        answers.feeling = feeling
        userSays(feeling)
        buildPlan()
    }

    private func submitReply() {
        let text = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        replyText = ""
        replyFocused = false
        switch step {
        case .feeling:
            answers.feeling = text
            userSays(text)
            buildPlan()
        case .plan:
            requestChange(text)
        default:
            break
        }
    }

    private func requestChange(_ text: String) {
        userSays(text)
        answers.notes.append(text)
        buildPlan()
    }

    private func buildPlan() {
        let previous = plan
        step = .building
        speech.stopAndClearQueue()
        Task {
            let newPlan = await planner.buildPlan(answers: answers, previous: previous, healthStore: healthStore)
            plan = newPlan
            coachSays(newPlan.intro)
            step = .plan
        }
    }

    private func startPlan(_ plan: TrainerPlan) {
        speech.stopAndClearQueue()
        switch plan.content {
        case .weights(let workout, let rest, let cues):
            onStartWeights(workout, rest, planner.warmupRest, cues)
        case .cardio(let cardio):
            onStartCardio(cardio)
        }
    }

    // MARK: - Plan card

    private func planCard(_ plan: TrainerPlan) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                GLMIconTile(glyph: planGlyph(plan))
                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.title).glmText(.rowTitle)
                        .lineLimit(2)
                    Text("About \(plan.estimatedMinutes) min").glmText(.caption)
                }
                Spacer()
            }

            switch plan.content {
            case .weights(let workout, let rest, _):
                VStack(spacing: 12) {
                    ForEach(workout.exercises.indices, id: \.self) { index in
                        liftRow(workout.exercises[index])
                    }
                }
                Text("\(rest / 60 > 0 ? "\(rest / 60) min" : "")\(rest % 60 > 0 ? " \(rest % 60)s" : "") rest between work sets")
                    .glmText(.readout)
            case .cardio(let cardio):
                cardioSummary(cardio)
            }

            if !plan.adjustments.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(plan.adjustments, id: \.self) { note in
                        Text("· \(note)").glmText(.caption, color: GLM.caution)
                    }
                }
            }

            Button("Let's go") { startPlan(plan) }
                .buttonStyle(.glmPrimary)
                .padding(.top, 4)
        }
        .glmCard(.featured)
    }

    private func planGlyph(_ plan: TrainerPlan) -> String {
        switch plan.content {
        case .weights: return "🏋️"
        case .cardio(let cardio): return cardio.activity.sessionKind.glyph
        }
    }

    private func liftRow(_ exercise: Exercise) -> some View {
        let weight = healthStore.getNextWorkWeight(for: exercise)
        let warmups = exercise.generateWarmupSets(weight).count
        let plates = exercise.getPlatesForWeight(weight)
        var meta = warmups > 0 ? "\(warmups)w + \(exercise.sets) × \(exercise.reps)" : "\(exercise.sets) × \(exercise.reps)"
        if !plates.isEmpty { meta += " · \(formatPlates(plates))" }

        return HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(exercise.name).glmText(.cardTitle)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(meta).glmText(.readout)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            Spacer()
            Text(exercise.isTimedExercise ? "Timed" : (weight > 0 ? GLMFormat.kg(weight) : "Bodyweight"))
                .glmText(.rowValue, color: GLM.cyan)
                .lineLimit(1)
        }
    }

    private func cardioSummary(_ cardio: CardioPlan) -> some View {
        let pace = TrainerContext.typicalPaceSeconds(for: cardio.activity, healthStore)
        let target: String
        switch cardio.goal.type {
        case .distance: target = String(format: "%.1f km", cardio.goal.distanceKm)
        case .time: target = "\(cardio.goal.timeMinutes) min"
        case .open: target = "Open"
        }
        return HStack(spacing: 10) {
            GLMInsetStatTile(value: target, label: cardio.activity == .run ? "run" : "walk")
            GLMInsetStatTile(value: "\(pace / 60):\(String(format: "%02d", pace % 60))", label: "usual /km", tone: GLM.cyan)
            GLMInsetStatTile(value: cardio.outdoor ? "Outside" : "Treadmill", label: "where")
        }
    }
}

#Preview {
    TrainerCheckInView(
        healthStore: HealthStore(),
        onBack: {},
        onStartWeights: { _, _, _, _ in },
        onStartCardio: { _ in }
    )
}
