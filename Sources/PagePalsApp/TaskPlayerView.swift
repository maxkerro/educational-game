import SwiftUI
import AppKit
import PagePalsCore

/// Plays one task on the original book page. The child sees exactly the page from the book;
/// the empty circles (numbers) or grey answer bars (sums) become input fields.
///  - `numberInOrder`: "put the right number into each circle". A grown-up types the correct numbers
///    once ("Set answers"); they are remembered on this Mac.
///  - `fillIn`: sums such as "three + one =". The answers are calculated, "4" and "four" both count.
/// Correct answers turn green, a wrong one is marked gently so the child can try again.
struct TaskPlayerView: View {
    let task: PlayTask
    let page: CGImage
    let onSaveKey: (AnswerKey) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var key: AnswerKey?
    @State private var answers: [String: String] = [:]
    @State private var submitted: Set<String> = []
    @State private var ticks: [String: Bool] = [:]   // tick tasks: row id -> true = "correct" circle
    @State private var authoring = false

    init(task: PlayTask, page: CGImage, onSaveKey: @escaping (AnswerKey) -> Void) {
        self.task = task
        self.page = page
        self.onSaveKey = onSaveKey
        _key = State(initialValue: task.key)
    }

    private var isNumberTask: Bool { task.kind == .numberInOrder }
    private var isTickTask: Bool { task.kind == .trueFalse }
    private var zone: PageRect { task.region ?? PageRect(x: 0, y: 0, width: 1, height: 1) }

    /// Words are judged when the child has typed as many letters as the answer has, or pressed Return.
    private func isJudged(_ id: String) -> Bool {
        if isNumberTask { return true }
        guard let given = answers[id], !given.isEmpty else { return false }
        if submitted.contains(id) { return true }
        guard let expected = key?.text[id] else { return false }
        // digits are judged as soon as there are as many as the answer needs ("4" for "four")
        if given.allSatisfy({ $0.isNumber }), let value = NumberWords.value(expected) {
            return given.count >= String(value).count
        }
        return given.count >= expected.count
    }

    private var response: AnswerKey {
        var response = AnswerKey()
        if isTickTask { response.booleans = ticks; return response }
        for (id, text) in answers where isJudged(id) {
            if isNumberTask {
                if let n = Int(text) { response.order[id] = n }
            } else {
                response.text[id] = text
            }
        }
        return response
    }

    private var evaluation: EvaluationResult? {
        guard !authoring, key != nil else { return nil }
        var playable = task
        playable.key = key
        return TaskEvaluator.evaluate(task: playable, response: response)
    }

    private var zoneImage: NSImage? {
        let rect = CGRect(
            x: zone.x * Double(page.width),
            y: zone.y * Double(page.height),
            width: zone.width * Double(page.width),
            height: zone.height * Double(page.height)
        ).integral.intersection(CGRect(x: 0, y: 0, width: page.width, height: page.height))
        guard !rect.isEmpty, let piece = page.cropping(to: rect) else { return nil }
        return NSImage(cgImage: piece, size: NSSize(width: piece.width, height: piece.height))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if let image = zoneImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .overlay(GeometryReader { geo in
                        ForEach(task.items) { item in
                            if let r = item.region {
                                if isTickTask {
                                    tickSlot(item, correct: r, wrong: item.secondRegion ?? r, in: geo.size)
                                } else {
                                    slot(item, rect: r, in: geo.size)
                                }
                            }
                        }
                    })
                    .padding(16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("This task has no picture of the page.").frame(maxHeight: .infinity)
            }
            Divider()
            footer
        }
        .frame(minWidth: 1000, minHeight: 800)
        // The book page is light, so the player is always light: dark text on white fields.
        .environment(\.colorScheme, .light)
        .background(Color.white)
    }

    private var header: some View {
        HStack {
            Text(task.prompt).font(.title2.weight(.semibold))
            Spacer()
            if let e = evaluation {
                Text("\(e.correct.count) of \(task.items.count) right")
                    .foregroundStyle(.secondary)
            }
            Button("Close") { dismiss() }
        }
        .padding(12)
    }

    @ViewBuilder
    private var footer: some View {
        HStack(spacing: 12) {
            if authoring {
                Text(isTickTask ? "Grown-up: tap the right circle in every row, then save."
                     : isNumberTask ? "Grown-up: type the correct number into every circle, then save."
                     : "Grown-up: type the correct answer into every box, then save.")
                Spacer()
                Button("Cancel") { authoring = false; answers = [:]; ticks = [:] }
                Button("Save answers") { saveKey() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!allFilled)
            } else if let e = evaluation, e.isComplete {
                Text("\u{2B50} All correct. Well done!").font(.title3.weight(.semibold))
                Spacer()
                Button("Done") { dismiss() }.buttonStyle(.borderedProminent)
            } else if key == nil {
                Text("The correct answers are not saved yet. A grown-up can enter them once.")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Set answers (grown-up)") { authoring = true; answers = [:]; ticks = [:] }
            } else if isTickTask {
                Text("Tap the right circle in each row.")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Change answers (grown-up)") { authoring = true; answers = [:]; ticks = [:] }
            } else if isNumberTask {
                Text("Type a number into each empty circle.")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Change answers (grown-up)") { authoring = true; answers = [:] }
            } else {
                Text("Write the answer into each grey box. A number or a word is fine.")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Change answers (grown-up)") { authoring = true; answers = [:] }
            }
        }
        .padding(12)
    }

    private var allFilled: Bool {
        if isTickTask { return task.items.allSatisfy { ticks[$0.id] != nil } }
        return task.items.allSatisfy { item in
            let given = answers[item.id] ?? ""
            return isNumberTask ? Int(given) != nil : !given.isEmpty
        }
    }

    private func saveKey() {
        var newKey = AnswerKey()
        if isTickTask { newKey.booleans = ticks }
        for item in task.items where !isTickTask {
            let given = answers[item.id] ?? ""
            if isNumberTask {
                if let n = Int(given) { newKey.order[item.id] = n }
            } else if !given.isEmpty {
                newKey.text[item.id] = given
            }
        }
        key = newKey
        onSaveKey(newKey)
        authoring = false
        answers = [:]
        ticks = [:]
    }

    @ViewBuilder
    private func slot(_ item: TaskItem, rect r: PageRect, in size: CGSize) -> some View {
        let barWidth = r.width / zone.width * size.width
        let barHeight = r.height / zone.height * size.height
        // circles: round and a little larger; bars: wider than the printed grey bar, and taller
        let w = isNumberTask ? max(barWidth * 1.15, 36) : max(barWidth, 90)
        let h = isNumberTask ? w : max(barHeight * 2.4, 34)
        let cx = (r.x + r.width / 2 - zone.x) / zone.width * size.width
        let cy = (r.y + r.height / 2 - zone.y) / zone.height * size.height
        let state = slotState(item.id)

        ZStack {
            shape(isCircle: isNumberTask).fill(fill(for: state))
            shape(isCircle: isNumberTask).stroke(stroke(for: state), lineWidth: 3)
            TextField("", text: Binding(
                get: { answers[item.id] ?? "" },
                set: { newValue in
                    submitted.remove(item.id)
                    answers[item.id] = isNumberTask
                        ? String(newValue.filter { $0.isNumber }.prefix(2))
                        : String(newValue.filter { $0.isLetter || $0.isNumber }.prefix(14))
                }
            ))
            .onSubmit { submitted.insert(item.id) }
            .textFieldStyle(.plain)
            .multilineTextAlignment(.center)
            .font(.system(size: h * (isNumberTask ? 0.62 : 0.55), weight: .heavy, design: .rounded))
            .foregroundStyle(textColor(for: state))
            .tint(textColor(for: state))
            .padding(.horizontal, h * 0.08)
        }
        .frame(width: w, height: h)
        .position(x: cx, y: cy)
    }

    /// A row of two tappable circles on top of the printed grey ones: "correct" and "wrong".
    @ViewBuilder
    private func tickSlot(_ item: TaskItem, correct: PageRect, wrong: PageRect, in size: CGSize) -> some View {
        let state = slotState(item.id)
        ZStack {
            tickCircle(item, side: true, rect: correct, in: size, state: state)
            tickCircle(item, side: false, rect: wrong, in: size, state: state)
        }
    }

    @ViewBuilder
    private func tickCircle(_ item: TaskItem, side: Bool, rect r: PageRect, in size: CGSize, state: SlotState) -> some View {
        let d = max(r.width / zone.width * size.width * 1.5, 26)
        let cx = (r.x + r.width / 2 - zone.x) / zone.width * size.width
        let cy = (r.y + r.height / 2 - zone.y) / zone.height * size.height
        let chosen = ticks[item.id] == side

        Button {
            ticks[item.id] = side
        } label: {
            ZStack {
                Circle().fill(chosen ? fill(for: state) : Color.white.opacity(0.01))
                Circle().stroke(chosen ? stroke(for: state) : Color.accentColor.opacity(0.35), lineWidth: chosen ? 4 : 2)
                if chosen {
                    Image(systemName: "checkmark")
                        .font(.system(size: d * 0.6, weight: .heavy))
                        .foregroundStyle(textColor(for: state))
                }
            }
            .frame(width: d, height: d)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .position(x: cx, y: cy)
    }

    private func shape(isCircle: Bool) -> AnyShape {
        isCircle ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: 8))
    }

    private enum SlotState { case neutral, correct, wrong, authoring }

    private func slotState(_ id: String) -> SlotState {
        if authoring { return .authoring }
        guard let e = evaluation else { return .neutral }
        if e.correct.contains(id) { return .correct }
        if e.incorrect.contains(id) { return .wrong }
        return .neutral
    }

    private func fill(for state: SlotState) -> Color {
        switch state {
        case .correct: return Color(red: 0.80, green: 0.95, blue: 0.80)
        case .wrong: return Color(red: 1.0, green: 0.88, blue: 0.70)
        case .authoring: return Color(red: 0.92, green: 0.86, blue: 0.98)
        case .neutral: return Color.white
        }
    }

    private func textColor(for state: SlotState) -> Color {
        switch state {
        case .correct: return Color(red: 0.05, green: 0.45, blue: 0.10)
        case .wrong: return Color(red: 0.75, green: 0.30, blue: 0.00)
        case .authoring: return Color(red: 0.35, green: 0.10, blue: 0.60)
        case .neutral: return Color(red: 0.08, green: 0.12, blue: 0.30)
        }
    }

    private func stroke(for state: SlotState) -> Color {
        switch state {
        case .correct: return .green
        case .wrong: return .orange
        case .authoring: return .purple
        case .neutral: return Color.accentColor.opacity(0.6)
        }
    }
}
