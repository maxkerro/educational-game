import SwiftUI
import PagePalsCore

/// First end-to-end slice: one hand-authored fill-in task, checked by the core evaluator.
/// Later this view is generated from a LessonPack produced by the PDF import pipeline.
struct ContentView: View {
    private let task = PlayTask(
        id: "demo-fill",
        kind: .fillIn,
        prompt: "How much is it? Write the answer in words.",
        items: [
            TaskItem(id: "a", label: "three + one ="),
            TaskItem(id: "b", label: "two + five ="),
            TaskItem(id: "c", label: "ten \u{2212} seven ="),
            TaskItem(id: "d", label: "nine \u{2212} eight =")
        ],
        key: AnswerKey(text: ["a": "four", "b": "seven", "c": "three", "d": "one"])
    )

    @State private var answers: [String: String] = [:]
    @State private var result = EvaluationResult()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(task.prompt)
                .font(.largeTitle.bold())

            ForEach(task.items) { item in
                HStack(spacing: 12) {
                    Text(item.label ?? "")
                        .font(.title2)
                        .frame(width: 180, alignment: .leading)
                    TextField("", text: binding(for: item.id))
                        .textFieldStyle(.roundedBorder)
                        .font(.title2)
                        .frame(width: 160)
                        .onSubmit(check)
                    status(for: item.id)
                }
            }

            HStack(spacing: 16) {
                Button("Check", action: check)
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.large)
                if result.isComplete {
                    Text("Great work!")
                        .font(.title2.bold())
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(32)
        .frame(minWidth: 560, minHeight: 420, alignment: .topLeading)
    }

    private func binding(for id: String) -> Binding<String> {
        Binding(get: { answers[id] ?? "" }, set: { answers[id] = $0 })
    }

    private func check() {
        result = TaskEvaluator.evaluate(task: task, response: AnswerKey(text: answers))
    }

    @ViewBuilder
    private func status(for id: String) -> some View {
        if result.correct.contains(id) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.title2)
        } else if result.incorrect.contains(id) {
            Image(systemName: "xmark.circle.fill").foregroundStyle(.red).font(.title2)
        }
    }
}
