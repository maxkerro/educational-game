import SwiftUI
import AppKit
import PagePalsCore

/// Plays one "put the right number into each circle" task on the original book page.
/// The child sees exactly the page from the book; the empty circles become input fields.
/// Correct numbers turn green, a wrong number is marked gently so the child can try again.
/// A grown-up types the correct numbers once ("Set answers"); they are remembered on this Mac.
struct TaskPlayerView: View {
    let task: PlayTask
    let page: CGImage
    let onSaveKey: (AnswerKey) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var key: AnswerKey?
    @State private var answers: [String: String] = [:]
    @State private var authoring = false

    init(task: PlayTask, page: CGImage, onSaveKey: @escaping (AnswerKey) -> Void) {
        self.task = task
        self.page = page
        self.onSaveKey = onSaveKey
        _key = State(initialValue: task.key)
    }

    private var zone: PageRect { task.region ?? PageRect(x: 0, y: 0, width: 1, height: 1) }

    private var response: AnswerKey {
        var order: [String: Int] = [:]
        for (id, text) in answers { if let n = Int(text) { order[id] = n } }
        return AnswerKey(order: order)
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
                                slot(item, rect: r, in: geo.size)
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
        // The book page is light, so the player is always light: dark numbers on white circles.
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
                Text("Grown-up: type the correct number into every circle, then save.")
                Spacer()
                Button("Cancel") { authoring = false; answers = [:] }
                Button("Save answers") { saveKey() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!allFilled)
            } else if let e = evaluation, e.isComplete {
                Text("\u{2B50} All correct. Well done!").font(.title3.weight(.semibold))
                Spacer()
                Button("Done") { dismiss() }.buttonStyle(.borderedProminent)
            } else if key == nil {
                Text("The correct numbers are not saved yet. A grown-up can enter them once.")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Set answers (grown-up)") { authoring = true; answers = [:] }
            } else {
                Text("Type a number into each empty circle.").foregroundStyle(.secondary)
                Spacer()
                Button("Change answers (grown-up)") { authoring = true; answers = [:] }
            }
        }
        .padding(12)
    }

    private var allFilled: Bool {
        task.items.allSatisfy { Int(answers[$0.id] ?? "") != nil }
    }

    private func saveKey() {
        var order: [String: Int] = [:]
        for item in task.items { if let n = Int(answers[item.id] ?? "") { order[item.id] = n } }
        let newKey = AnswerKey(order: order)
        key = newKey
        onSaveKey(newKey)
        authoring = false
        answers = [:]
    }

    @ViewBuilder
    private func slot(_ item: TaskItem, rect r: PageRect, in size: CGSize) -> some View {
        let d = max(r.width / zone.width * size.width * 1.15, 36)
        let cx = (r.x + r.width / 2 - zone.x) / zone.width * size.width
        let cy = (r.y + r.height / 2 - zone.y) / zone.height * size.height
        let state = slotState(item.id)

        ZStack {
            Circle().fill(fill(for: state))
            Circle().stroke(stroke(for: state), lineWidth: 4)
            TextField("", text: Binding(
                get: { answers[item.id] ?? "" },
                set: { answers[item.id] = String($0.filter { $0.isNumber }.prefix(2)) }
            ))
            .textFieldStyle(.plain)
            .multilineTextAlignment(.center)
            .font(.system(size: d * 0.62, weight: .heavy, design: .rounded))
            .foregroundStyle(textColor(for: state))
            .tint(textColor(for: state))
            .padding(.horizontal, d * 0.05)
        }
        .frame(width: d, height: d)
        .position(x: cx, y: cy)
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
